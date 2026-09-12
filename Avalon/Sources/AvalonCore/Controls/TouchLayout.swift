// Avalon — touch control layouts.
//
// The shape of this subsystem is muffin's. `cemu-ios-muffin/src/ios/App/ControllerSkinPalette.swift`
// keeps a skin as a small set of named colour tokens rather than a bitmap, and
// `cemu-ios-muffin/src/ios/App/ControllerSkinsLibrary.swift` keeps the catalogue of those token sets separate from the
// geometry that uses them. That separation is the whole reason one art direction can be
// re-skinned twenty-two ways without redrawing anything, and Avalon keeps it.
//
// What Avalon does NOT keep is muffin's single controller. Delta ships one skin per system
// (`Delta/Delta/Resources/Controller Skins/`) and Manic EMU ships `.manicskin` bundles per
// system — both are right that a GameCube layout is not a Switch layout with different colours.
// So geometry here is per platform and describes the real hardware: the GameCube's oversized A
// with satellites, the N64's C-cluster, the Deck's two trackpads.
//
// Three properties are load-bearing, and each one is here because its absence caused a real bug
// while this layout set was being designed:
//
//   1. Every control is centre-positioned. The design data mixed centres (round things) with
//      top-left corners (bars), and a trackpad went out of bounds because the two conventions
//      were crossed.
//   2. Every control anchors to a screen EDGE, not to a fraction of the canvas. Positions
//      expressed as a percentage of width collapse the moment the device aspect ratio differs
//      from the one they were drawn at; anchoring to an edge in scaled design units does not.
//   3. Buttons that form a cluster — a diamond, a C-pad, an arcade grid — carry one shared
//      anchor and a rigid offset from it, so the cluster travels as a single object. Members
//      that each picked their own edge tore the cluster in half on a different aspect ratio.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

// MARK: - Geometry

/// A point in device space (points, origin top-left).
public struct LayoutPoint: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// An axis-aligned rectangle in device space.
public struct LayoutRect: Hashable, Sendable {
    public var x: Double, y: Double, width: Double, height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public init(centre: LayoutPoint, width: Double, height: Double) {
        self.init(x: centre.x - width / 2, y: centre.y - height / 2, width: width, height: height)
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var centre: LayoutPoint { LayoutPoint(x: x + width / 2, y: y + height / 2) }

    public func contains(_ p: LayoutPoint) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }

    public func intersects(_ other: LayoutRect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    /// Overlap along each axis. Negative means a gap; the larger value is the separating axis.
    public func overlap(_ other: LayoutRect) -> (x: Double, y: Double) {
        (min(maxX, other.maxX) - max(minX, other.minX),
         min(maxY, other.maxY) - max(minY, other.minY))
    }

    public func inset(by d: Double) -> LayoutRect {
        LayoutRect(x: x + d, y: y + d, width: width - 2 * d, height: height - 2 * d)
    }

    public func inflated(by d: Double) -> LayoutRect { inset(by: -d) }

    /// Largest rect of the given width:height ratio that fits, centred.
    public func fittingAspect(_ aspect: Double) -> LayoutRect {
        guard aspect > 0, width > 0, height > 0 else { return LayoutRect(x: x, y: y, width: 0, height: 0) }
        var w = width, h = width / aspect
        if h > height { h = height; w = height * aspect }
        return LayoutRect(x: x + (width - w) / 2, y: y + (height - h) / 2, width: w, height: h)
    }
}

// MARK: - Model

public enum ControlKind: String, Codable, Sendable {
    case button, pill, shoulder, dpad, stick, trackpad

    /// Round controls are hit-tested and spaced as circles; a circle inscribed in its box.
    public var isRound: Bool { self == .button || self == .stick }
}

public enum EdgeX: String, Codable, Sendable { case left, right }
public enum EdgeY: String, Codable, Sendable { case top, bottom }

/// One control, positioned in design units relative to a screen edge.
public struct TouchControl: Codable, Sendable, Hashable, Identifiable {
    public let kind: ControlKind
    public let id: String
    /// Non-nil when this control moves rigidly with others sharing the name.
    public let cluster: String?
    public let anchorX: EdgeX
    public let anchorY: EdgeY
    /// Distance from the anchored edges to the cluster's anchor point, in design units.
    public let offsetX: Double
    public let offsetY: Double
    /// This control's centre relative to the cluster anchor point, in design units.
    public let dx: Double
    public let dy: Double
    public let width: Double
    public let height: Double
    public let fill: String
    public let label: String?
    public let labelColor: String?
    public let capFill: String?
    /// A stick that reports the four directions rather than an axis — an arcade lever.
    public let digital: Bool?
    /// The Avalon controls this drives, as binding names (see `ControlBinding`).
    public let binds: [String]

    public var bindings: [ControlBinding] { binds.compactMap(ControlBinding.init(name:)) }
    public var isDigitalStick: Bool { digital == true }
}

/// A binding name from the layout resource: a control, optionally pinned to one axis extreme.
///
/// The N64's C-buttons are the case that needs this. They are four discrete buttons that between
/// them do the job the right stick does on every later pad, so each binds to one extreme of one
/// axis — `rightStickX-` is the left C-button.
public struct ControlBinding: Hashable, Sendable {
    public let control: Control
    /// +1 or −1. Only meaningful for a digital press onto an analog control.
    public let polarity: Double

    public init(control: Control, polarity: Double = 1) {
        self.control = control
        self.polarity = polarity < 0 ? -1 : 1
    }

    public init?(name: String) {
        var base = name
        var polarity = 1.0
        if base.hasSuffix("+") { base.removeLast() }
        else if base.hasSuffix("-") { base.removeLast(); polarity = -1 }
        guard let control = Control(avalonName: base) else { return nil }
        self.init(control: control, polarity: polarity)
    }
}

public extension Control {
    /// The name this control carries in the layout resource.
    var avalonName: String {
        switch self {
        case .up: return "up"; case .down: return "down"
        case .left: return "left"; case .right: return "right"
        case .a: return "a"; case .b: return "b"; case .x: return "x"; case .y: return "y"
        case .l1: return "l1"; case .r1: return "r1"; case .l2: return "l2"
        case .r2: return "r2"; case .l3: return "l3"; case .r3: return "r3"
        case .start: return "start"; case .select: return "select"; case .home: return "home"
        case .leftStickX: return "leftStickX"; case .leftStickY: return "leftStickY"
        case .rightStickX: return "rightStickX"; case .rightStickY: return "rightStickY"
        case .touchX: return "touchX"; case .touchY: return "touchY"; case .touch: return "touch"
        case .accelerometerX: return "accelerometerX"; case .accelerometerY: return "accelerometerY"
        case .accelerometerZ: return "accelerometerZ"
        case .gyroX: return "gyroX"; case .gyroY: return "gyroY"; case .gyroZ: return "gyroZ"
        }
    }

    init?(avalonName: String) {
        guard let match = Control.allCases.first(where: { $0.avalonName == avalonName }) else { return nil }
        self = match
    }
}

/// One platform's control layout, authored on its own design canvas.
public struct TouchLayout: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let system: SystemIdentifier
    public let name: String
    public let year: String
    /// The specific hardware this layout is of, e.g. "DualShock SCPH-1200".
    public let hardware: String
    /// Why the layout is arranged the way it is. Shown in the layout picker.
    public let rationale: String
    /// The console's real display aspect ratio; the game rect is built from this, never guessed.
    public let screenAspect: Double
    public let designWidth: Double
    public let designHeight: Double
    public let bodyFill: String
    public let bodyStroke: String
    public let bodyRadius: Double
    public let bodyShadow: Double
    public let controls: [TouchControl]

    public func control(id: String) -> TouchControl? { controls.first { $0.id == id } }

    /// Every Avalon control this layout can produce.
    public var reachableControls: Set<Control> {
        Set(controls.flatMap { $0.bindings.map(\.control) })
    }
}

// MARK: - Library

public enum LayoutLibraryError: Error, Equatable {
    case resourceMissing(String)
    case malformed(String)
}

/// The built-in layouts, loaded from `Resources/controls.json`.
public struct TouchLayoutLibrary: Sendable {
    public let layouts: [TouchLayout]

    public init(layouts: [TouchLayout]) { self.layouts = layouts }

    private struct Document: Codable { let version: Int; let platforms: [TouchLayout] }

    public static func builtIn() throws -> TouchLayoutLibrary {
        guard let url = Bundle.module.url(forResource: "controls", withExtension: "json") else {
            throw LayoutLibraryError.resourceMissing("controls.json")
        }
        return try load(contentsOf: url)
    }

    public static func load(contentsOf url: URL) throws -> TouchLayoutLibrary {
        let data = try Data(contentsOf: url)
        let doc: Document
        do { doc = try JSONDecoder().decode(Document.self, from: data) }
        catch { throw LayoutLibraryError.malformed("\(url.lastPathComponent): \(error)") }
        guard doc.version == 1 else {
            throw LayoutLibraryError.malformed("unsupported layout version \(doc.version)")
        }
        return TouchLayoutLibrary(layouts: doc.platforms)
    }

    public func layout(id: String) -> TouchLayout? { layouts.first { $0.id == id } }

    public func layouts(for system: SystemIdentifier) -> [TouchLayout] {
        layouts.filter { $0.system == system }
    }
}
