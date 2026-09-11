// Avalon — input abstraction.
//
// This is the subsystem with the clearest gap in the source projects. Folium has no normalization
// at all: every core takes `press_button(uint32_t)` with its own raw encoding — the NDS hardware
// KEYINPUT mask (`Folium/Grape/Grape.swift:11-26`), Gambatte's mask (`Kiwi.swift:15-27`), and
// arbitrary integers 700–782 for the 3DS (`Cytrus.swift:12-40`) — so its "controls controller" is
// ten overloads of `press(button:using:)`, one per concrete enum
// (`Folium/.../ControlsController.swift:20-118`).
//
// Delta gets this right and is the model here: one receiver graph where the same mapping serves
// touch skins, MFi controllers and keyboards uniformly, keyed per (player, system, controller type)
// (`Delta/.../GameViewController.swift:874-916`, `Delta/.../GameControllerInputMapping.swift:39-62`).
// Manic EMU regressed it by dropping the player index (`.../ControllerMapping.swift:16-28`), which
// is why it cannot map two players independently.
//
// Avalon normalizes to a device-independent control, then translates to the core's own encoding at
// exactly one place: the core's `inputMap`.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A control as Avalon understands it, independent of any console's bit layout.
public enum Control: Hashable, Sendable, CaseIterable {
    case up, down, left, right
    case a, b, x, y
    case l1, r1, l2, r2, l3, r3
    case start, select, home
    case leftStickX, leftStickY, rightStickX, rightStickY
    case touchX, touchY, touch
    case accelerometerX, accelerometerY, accelerometerZ
    case gyroX, gyroY, gyroZ

    /// Whether this control carries a continuous value rather than pressed/released.
    /// Delta models the same distinction with `isContinuous` (`Cores/ThreeDS.swift:56-60`).
    public var isAnalog: Bool {
        switch self {
        case .leftStickX, .leftStickY, .rightStickX, .rightStickY,
             .touchX, .touchY, .l2, .r2,
             .accelerometerX, .accelerometerY, .accelerometerZ,
             .gyroX, .gyroY, .gyroZ:
            return true
        default: return false
        }
    }
}

/// Where an input came from. Kept so a mapping can differ per device class, as Delta's does.
public enum InputDevice: Hashable, Sendable {
    case touchOverlay
    case mfiController(id: String)
    case keyboard
    case motion
}

/// One normalized input event.
public struct InputEvent: Hashable, Sendable {
    public let control: Control
    /// 0…1 for buttons, −1…1 for axes.
    public let value: Double
    public let playerIndex: Int
    public let device: InputDevice

    public init(control: Control, value: Double, playerIndex: Int = 0, device: InputDevice) {
        self.control = control
        self.playerIndex = playerIndex
        self.device = device
        self.value = control.isAnalog ? min(1, max(-1, value)) : min(1, max(0, value))
    }

    public var isPressed: Bool { abs(value) > 0.5 }
}

/// Translates Avalon controls into the integer a specific core expects.
///
/// Every per-core encoding oddity lives here and nowhere else. A core implementation calls
/// `activate(input:value:playerIndex:)` with the result and never sees a `Control`.
public struct CoreInputMap: Sendable {
    public let coreID: String
    private let mapping: [Control: Int]

    public init(coreID: String, mapping: [Control: Int]) {
        self.coreID = coreID; self.mapping = mapping
    }

    public func rawValue(for control: Control) -> Int? { mapping[control] }
    public var supportedControls: Set<Control> { Set(mapping.keys) }
    public func supports(_ control: Control) -> Bool { mapping[control] != nil }
}

/// A user-editable binding from a physical input to an Avalon control.
public struct InputBinding: Hashable, Sendable {
    public let device: InputDevice
    /// Platform key/button code.
    public let code: Int
    public let control: Control
    public let playerIndex: Int

    public init(device: InputDevice, code: Int, control: Control, playerIndex: Int = 0) {
        self.device = device; self.code = code; self.control = control; self.playerIndex = playerIndex
    }
}

/// Per (system, device, player) bindings — the key Delta uses and Manic EMU dropped.
public struct InputMapping: Sendable {
    public let system: SystemIdentifier
    private var bindings: [BindingKey: Control] = [:]

    private struct BindingKey: Hashable { let device: InputDevice; let code: Int; let player: Int }

    public init(system: SystemIdentifier, bindings: [InputBinding] = []) {
        self.system = system
        for b in bindings { self.bindings[BindingKey(device: b.device, code: b.code, player: b.playerIndex)] = b.control }
    }

    public mutating func bind(_ b: InputBinding) {
        bindings[BindingKey(device: b.device, code: b.code, player: b.playerIndex)] = b.control
    }

    public mutating func unbind(device: InputDevice, code: Int, playerIndex: Int = 0) {
        bindings[BindingKey(device: device, code: code, player: playerIndex)] = nil
    }

    public func control(for device: InputDevice, code: Int, playerIndex: Int = 0) -> Control? {
        bindings[BindingKey(device: device, code: code, player: playerIndex)]
    }

    public var bindingCount: Int { bindings.count }
}

/// Routes normalized events to a core, holding the current state of every control.
///
/// Holding state is what makes `resetInputs()` correct and makes "sustain" possible; Delta needs
/// the same thing for its sustained-input feature.
public final class InputRouter {
    public private(set) var map: CoreInputMap
    private var state: [Int: [Control: Double]] = [:]   // player -> control -> value
    private let deadzone: Double

    /// Events the core cannot represent, recorded rather than silently dropped.
    public private(set) var unmappedControls: Set<Control> = []

    public init(map: CoreInputMap, deadzone: Double = 0.15) {
        self.map = map
        self.deadzone = max(0, min(0.9, deadzone))
    }

    /// Apply an event. Returns the core-space instruction to issue, or nil if nothing changed.
    @discardableResult
    public func handle(_ event: InputEvent) -> (raw: Int, value: Double, player: Int)? {
        guard let raw = map.rawValue(for: event.control) else {
            unmappedControls.insert(event.control)
            return nil
        }
        var value = event.value
        if event.control.isAnalog, abs(value) < deadzone {
            value = 0
        } else if event.control.isAnalog {
            // Rescale past the deadzone so the usable range stays full-scale rather than jumping.
            let sign = value < 0 ? -1.0 : 1.0
            value = sign * (abs(value) - deadzone) / (1 - deadzone)
        }
        if state[event.playerIndex]?[event.control] == value { return nil }
        state[event.playerIndex, default: [:]][event.control] = value
        return (raw, value, event.playerIndex)
    }

    public func value(of control: Control, player: Int = 0) -> Double {
        state[player]?[control] ?? 0
    }

    public var activeControls: [(control: Control, player: Int, value: Double)] {
        state.flatMap { player, m in
            m.filter { $0.value != 0 }.map { (control: $0.key, player: player, value: $0.value) }
        }
    }

    public func reset() { state.removeAll() }
}
