// Avalon — turning touches into inputs.
//
// Folium is the cautionary example. Its touch handling calls straight into each core's own
// encoding (`Folium/Folium/Controllers/Emulation/ControlsController.swift:20-118` is ten
// overloads of `press(button:using:)`, one per core enum), so the d-pad's diagonal behaviour,
// the stick's deadzone and the analog trigger's curve are each re-decided per core, or not
// decided at all. Delta routes touches through the same receiver graph as everything else and is
// the model here.
//
// This router emits `InputEvent`s and nothing else. It knows about circles, boxes and diagonals;
// it does not know what a Nintendo 64 is. `InputRouter` then translates to the core's encoding at
// the single place that is allowed to know.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// One finger on the glass.
public struct Touch: Hashable, Sendable, Identifiable {
    public let id: Int
    public let location: LayoutPoint
    public init(id: Int, location: LayoutPoint) { self.id = id; self.location = location }
}

/// Translates touches on a resolved layout into normalized input events.
///
/// The router is stateful because releases matter: a finger that leaves a button has to produce
/// the zero, and a finger that slides off the edge of a d-pad has to release the direction it was
/// holding. Comparing this frame's active set against the last one is what produces both.
public final class TouchRouter {
    public private(set) var layout: ResolvedLayout
    public var playerIndex: Int

    /// D-pad centre deadzone, as a fraction of half the pad. Below this nothing is pressed, which
    /// stops a resting thumb from drifting into a direction.
    public var dpadDeadzone: Double = 0.22

    /// Fraction of the pad's half-width a diagonal needs on the minor axis. Real d-pads engage
    /// both switches over roughly the middle half of each quadrant.
    public var diagonalThreshold: Double = 0.38

    private var held: [Control: Double] = [:]
    /// Which control a given finger is driving, so it keeps that control while it slides.
    private var capture: [Int: String] = [:]

    public init(layout: ResolvedLayout, playerIndex: Int = 0) {
        self.layout = layout
        self.playerIndex = playerIndex
    }

    /// Replace the resolved layout (rotation, a resize, a different skin). Anything held is
    /// released first, so a control that moved out from under a finger cannot stay stuck down.
    public func update(layout: ResolvedLayout) -> [InputEvent] {
        let released = releaseAll()
        self.layout = layout
        return released
    }

    /// The complete set of events for this frame's touches, including releases for anything that
    /// was held last frame and is not held now.
    public func process(touches: [Touch]) -> [InputEvent] {
        var values: [Control: Double] = [:]
        var newCapture: [Int: String] = [:]

        for touch in touches {
            let target = capture[touch.id].flatMap { retained(id: $0, at: touch.location) }
                ?? hitTest(touch.location)

            guard let control = target else { continue }
            newCapture[touch.id] = control.id
            emit(control, at: touch.location, into: &values)
        }
        capture = newCapture

        var events: [InputEvent] = []
        for (control, value) in values where held[control] != value {
            events.append(InputEvent(control: control, value: value,
                                     playerIndex: playerIndex, device: .touchOverlay))
        }
        for (control, previous) in held where values[control] == nil && previous != 0 {
            events.append(InputEvent(control: control, value: 0,
                                     playerIndex: playerIndex, device: .touchOverlay))
        }
        held = values
        return events
    }

    /// Zero everything currently held. Call on backgrounding, or the game keeps running forward.
    public func releaseAll() -> [InputEvent] {
        let events = held.filter { $0.value != 0 }.map {
            InputEvent(control: $0.key, value: 0, playerIndex: playerIndex, device: .touchOverlay)
        }
        held.removeAll()
        capture.removeAll()
        return events
    }

    public func value(of control: Control) -> Double { held[control] ?? 0 }

    /// Whether a finger already driving a control keeps driving it at this position.
    ///
    /// The rule differs by kind, and it has to. A stick or a d-pad that let go the moment the
    /// finger left its circle would be unusable — every virtual stick in every emulator tracks
    /// the finger across the whole screen once it is engaged, and releases only when it lifts.
    /// A button is the opposite case: it keeps a small slide margin so rolling a thumb over its
    /// edge does not drop the press, and beyond that the finger has genuinely left it.
    private func retained(id: String, at p: LayoutPoint) -> SolvedControl? {
        guard let c = layout.control(id: id) else { return nil }
        switch c.kind {
        case .stick, .dpad, .trackpad:
            return c
        case .button, .pill, .shoulder:
            return c.hitFrame.inflated(by: Self.slideMargin).contains(p) ? c : nil
        }
    }

    /// How far a thumb may roll past a button's edge and still hold it down.
    public static let slideMargin: Double = 12

    // MARK: - Hit testing

    /// Topmost control under the point. Round controls test as circles so the corners of a
    /// button's box belong to whatever is behind them, not to the button.
    public func hitTest(_ p: LayoutPoint) -> SolvedControl? {
        var best: SolvedControl?
        var bestDistance = Double.greatestFiniteMagnitude
        for c in layout.controls {
            let d: Double
            if c.kind.isRound {
                let r = hypot(p.x - c.hitFrame.centre.x, p.y - c.hitFrame.centre.y)
                guard r <= c.hitRadius else { continue }
                d = r
            } else {
                guard c.hitFrame.contains(p) else { continue }
                d = hypot(p.x - c.hitFrame.centre.x, p.y - c.hitFrame.centre.y)
            }
            if d < bestDistance { bestDistance = d; best = c }
        }
        return best
    }

    // MARK: - Per-kind behaviour

    private func emit(_ c: SolvedControl, at p: LayoutPoint, into values: inout [Control: Double]) {
        switch c.kind {
        case .button, .pill, .shoulder:
            for b in c.source.bindings {
                // An analog control driven by a digital press goes to its extreme: a touch
                // trigger is all the way down, and an N64 C-button is one end of one axis.
                values[b.control] = b.polarity
            }
        case .dpad:
            let half = c.frame.width / 2
            guard half > 0 else { return }
            let nx = (p.x - c.centre.x) / half
            let ny = (p.y - c.centre.y) / half
            let m = max(abs(nx), abs(ny))
            guard m >= dpadDeadzone else { return }
            // The major axis always engages; the minor one joins in over the middle of the
            // quadrant, which is how a real cross-pad's four switches behave.
            if abs(nx) >= diagonalThreshold * m || abs(nx) >= abs(ny) {
                values[nx < 0 ? .left : .right] = 1
            }
            if abs(ny) >= diagonalThreshold * m || abs(ny) >= abs(nx) {
                values[ny < 0 ? .up : .down] = 1
            }
        case .stick:
            let r = c.radius
            guard r > 0 else { return }
            var vx = (p.x - c.centre.x) / r
            var vy = (p.y - c.centre.y) / r
            let m = hypot(vx, vy)
            if m > 1 { vx /= m; vy /= m }     // clamp to the gate, never past full deflection
            if c.source.isDigitalStick {
                // An arcade lever is four microswitches; it has no in-between.
                if abs(vx) >= dpadDeadzone { values[vx < 0 ? .left : .right] = 1 }
                if abs(vy) >= dpadDeadzone { values[vy < 0 ? .up : .down] = 1 }
                return
            }
            for b in c.source.bindings {
                switch b.control {
                case .leftStickX, .rightStickX: values[b.control] = vx
                // Screen y grows downward and a stick's y grows upward.
                case .leftStickY, .rightStickY: values[b.control] = -vy
                default: break
                }
            }
        case .trackpad:
            let u = (p.x - c.frame.minX) / max(c.frame.width, 1)
            let v = (p.y - c.frame.minY) / max(c.frame.height, 1)
            for b in c.source.bindings {
                switch b.control {
                case .touchX: values[.touchX] = min(1, max(0, u))
                case .touchY: values[.touchY] = min(1, max(0, v))
                case .touch: values[.touch] = 1
                case .rightStickX: values[.rightStickX] = min(1, max(-1, u * 2 - 1))
                case .rightStickY: values[.rightStickY] = min(1, max(-1, 1 - v * 2))
                default: break
                }
            }
        }
    }
}
