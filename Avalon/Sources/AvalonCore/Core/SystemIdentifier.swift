// Avalon — system identity.
//
// Deliberately an open string, not an enum. Delta's `GameType` works the same way
// (`GameType("public.aoshuang.game.fds")`, `Manic EMU/.../Cores/FDS.swift:14`) and it is the reason
// adding a system to Delta needs no change to DeltaCore itself. Avalon keeps that property: a closed
// enum here would make every new core a breaking change to the package that defines the contract.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// The system a core emulates, as a reverse-DNS-style identifier.
public struct SystemIdentifier: Hashable, Codable, Sendable, RawRepresentable,
                                ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public extension SystemIdentifier {
    // Systems with a real core somewhere in this repository. Each cites where.
    static let nes: Self            = "com.avalon.system.nes"
    static let snes: Self           = "com.avalon.system.snes"
    static let gameBoy: Self        = "com.avalon.system.gameboy"
    static let gameBoyAdvance: Self = "com.avalon.system.gba"
    static let nintendo64: Self     = "com.avalon.system.n64"
    static let nintendoDS: Self     = "com.avalon.system.nds"
    static let nintendo3DS: Self    = "com.avalon.system.3ds"
    static let gameCube: Self       = "com.avalon.system.gamecube"   // Dolphin family
    static let wii: Self            = "com.avalon.system.wii"        // Dolphin family
    static let switchNX: Self       = "com.avalon.system.switch"     // MeloNX
    static let genesis: Self        = "com.avalon.system.genesis"
    static let playStation: Self    = "com.avalon.system.ps1"        // Folium/Mandarine
    static let playStation2: Self   = "com.avalon.system.ps2"        // Play! and iPSX2
    static let psp: Self            = "com.avalon.system.psp"        // PPSSPP
    static let colecoVision: Self   = "com.avalon.system.colecovision" // Folium/Cherry — unique here
    static let wonderSwan: Self     = "com.avalon.system.wonderswan"   // Folium/Durian — unique here
}
