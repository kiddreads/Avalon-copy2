// Avalon — control skins.
//
// Straight from muffin: a skin is a handful of named colour tokens, not artwork
// (`cemu-ios-muffin/src/ios/App/ControllerSkinPalette.swift`), catalogued separately from the
// geometry that consumes it (`cemu-ios-muffin/src/ios/App/ControllerSkinsLibrary.swift`). Twenty-two skins exist there and
// none of them required redrawing a button, which is the point.
//
// Avalon changes one thing about how they apply. In muffin a skin colours the whole controller,
// so every system comes out looking the same. Here a layout carries its own hardware colourway —
// a GameCube is indigo with a big green A whoever is looking at it — and a skin can either leave
// that alone (`.hardware`) or repaint it (`.recolour`). The default is to leave it alone, because
// a platform's real colours are the thing that makes it recognisable at a glance.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A colour with an alpha, as a skin stores it.
public struct SkinColor: Codable, Hashable, Sendable {
    public let hex: String
    public let alpha: Double

    public init(hex: String, alpha: Double = 1) { self.hex = hex; self.alpha = alpha }

    /// Red, green, blue in 0…1. Returns nil for a malformed hex string rather than guessing.
    public var components: (r: Double, g: Double, b: Double)? {
        var s = Substring(hex)
        if s.hasPrefix("#") { s = s.dropFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt32(s.prefix(6), radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF) / 255,
                Double((v >> 8) & 0xFF) / 255,
                Double(v & 0xFF) / 255)
    }

    /// Effective alpha, including an alpha baked into an 8-digit hex string.
    public var effectiveAlpha: Double {
        var s = Substring(hex)
        if s.hasPrefix("#") { s = s.dropFirst() }
        guard s.count == 8, let v = UInt32(s.suffix(2), radix: 16) else { return alpha }
        return alpha * Double(v) / 255
    }
}

public struct ControlSkin: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let dpad: SkinColor
    public let a: SkinColor
    public let b: SkinColor
    public let x: SkinColor
    public let y: SkinColor
    public let bg: SkinColor
    public let border: SkinColor
    public let shadow: Double
    public let radius: Double

    /// The colour this skin would give a control, or nil where it has no opinion and the
    /// hardware's own colour should stand.
    public func color(forControlID controlID: String) -> SkinColor? {
        switch controlID.uppercased() {
        case "A", "✕", "1": return a
        case "B", "○", "2": return b
        case "X", "□", "4": return x
        case "Y", "△", "5": return y
        case "DPAD": return dpad
        default: return nil
        }
    }
}

/// How a skin is applied over a platform's own colourway.
public enum SkinApplication: String, Sendable, CaseIterable {
    /// Keep the real hardware's colours; the skin only supplies body, border and shadow.
    case hardware
    /// Repaint the face buttons and d-pad in the skin's colours too.
    case recolour
}

public struct ControlSkinLibrary: Sendable {
    public let skins: [ControlSkin]

    public init(skins: [ControlSkin]) { self.skins = skins }

    private struct Document: Codable { let version: Int; let skins: [ControlSkin] }

    public static func builtIn() throws -> ControlSkinLibrary {
        guard let url = Bundle.module.url(forResource: "controlskins", withExtension: "json") else {
            throw LayoutLibraryError.resourceMissing("controlskins.json")
        }
        let data = try Data(contentsOf: url)
        let doc: Document
        do { doc = try JSONDecoder().decode(Document.self, from: data) }
        catch { throw LayoutLibraryError.malformed("controlskins.json: \(error)") }
        guard doc.version == 1 else {
            throw LayoutLibraryError.malformed("unsupported skin version \(doc.version)")
        }
        return ControlSkinLibrary(skins: doc.skins)
    }

    public func skin(id: String) -> ControlSkin? { skins.first { $0.id == id } }

    /// The skin whose name matches a platform's own hardware, when one exists. This is what makes
    /// "look like the real thing" the default rather than an option somebody has to find.
    public func nativeSkin(for layout: TouchLayout) -> ControlSkin? {
        let native = [
            "nes": "nes", "snes": "superNintendo", "genesis": "segaGenesis",
            "ps": "playStation", "n64": "nintendo64", "gc": "gameCube",
            "wiiu": "wiiUOriginal", "switch": "switchPro", "xbox": "xbox",
            "deck": "steamDeck", "arcade": "arcadeCabinet",
        ]
        return native[layout.id].flatMap(skin(id:))
    }
}

/// The colours a renderer should actually use for one control, after a skin is applied.
public struct ResolvedControlStyle: Sendable, Hashable {
    public let fill: SkinColor
    public let labelColor: SkinColor?
    public let capFill: SkinColor?

    public static func resolve(_ control: TouchControl,
                               skin: ControlSkin?,
                               application: SkinApplication = .hardware) -> ResolvedControlStyle {
        let hardware = SkinColor(hex: control.fill)
        let fill: SkinColor
        if application == .recolour, let skinned = skin?.color(forControlID: control.id) {
            fill = skinned
        } else {
            fill = hardware
        }
        return ResolvedControlStyle(
            fill: fill,
            labelColor: control.labelColor.map { SkinColor(hex: $0) },
            capFill: control.capFill.map { SkinColor(hex: $0) })
    }
}
