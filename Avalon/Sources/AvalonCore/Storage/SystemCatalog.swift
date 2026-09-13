// Avalon — what a file is, and whether Avalon can run it.
//
// A frontend needs to answer two questions about a file a player just imported: which system is
// this, and can we actually play it. Every project here answers the first one and none of them
// answers the second honestly — Manic EMU advertises "40+ systems via libretro" and then gates
// several of those cores behind a non-commercial licence, and Folium's picker offers systems whose
// cores need system files the user does not have.
//
// So `CoreStatus` is part of the model rather than a UI string. A system with no core says so, in
// the library, before a player taps it — the alternative is an app that looks like it supports
// twelve consoles and runs one.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Whether Avalon can actually run a system today.
public enum CoreStatus: Hashable, Sendable {
    /// A core is wired up and runs through `CoreSession`.
    case available(coreID: String)
    /// No core yet. The note says what it would take, so the library can be honest about it.
    case notYet(note: String)

    public var isAvailable: Bool { if case .available = self { return true }; return false }
}

/// One system Avalon knows about: how to recognise its files, which control layout it uses, and
/// whether there is a core behind it.
public struct SystemProfile: Hashable, Sendable, Identifiable {
    public let id: SystemIdentifier
    public let displayName: String
    public let shortName: String
    /// Lowercase, no dot. Order matters only within a system.
    public let fileExtensions: [String]
    /// `TouchLayout.id` this system plays with.
    public let layoutID: String
    public let coreStatus: CoreStatus

    public init(id: SystemIdentifier, displayName: String, shortName: String,
                fileExtensions: [String], layoutID: String, coreStatus: CoreStatus) {
        self.id = id; self.displayName = displayName; self.shortName = shortName
        self.fileExtensions = fileExtensions; self.layoutID = layoutID; self.coreStatus = coreStatus
    }
}

public enum SystemCatalog {

    // `.chip8` is declared in Chip8Core.swift, next to the core that implements it.
    public static let wiiU: SystemIdentifier = "com.avalon.system.wiiu"

    /// Ordered roughly by how likely a player is to have one, which is also the library's order.
    public static let all: [SystemProfile] = [
        SystemProfile(id: .nes, displayName: "Nintendo Entertainment System", shortName: "NES",
                      fileExtensions: ["nes", "unf", "unif", "fds"], layoutID: "nes",
                      coreStatus: .available(coreID: NestopiaSpec.coreID)),
        SystemProfile(id: .snes, displayName: "Super Nintendo", shortName: "SNES",
                      fileExtensions: ["sfc", "smc", "swc", "fig"], layoutID: "snes",
                      coreStatus: .available(coreID: BsnesSpec.coreID)),
        SystemProfile(id: .gameBoy, displayName: "Game Boy", shortName: "GB",
                      fileExtensions: ["gb", "gbc"], layoutID: "nes",
                      coreStatus: .available(coreID: MGBASpec.coreID)),
        SystemProfile(id: .gameBoyAdvance, displayName: "Game Boy Advance", shortName: "GBA",
                      fileExtensions: ["gba"], layoutID: "snes",
                      coreStatus: .available(coreID: MGBASpec.coreID)),
        SystemProfile(id: .genesis, displayName: "Sega Genesis", shortName: "Genesis",
                      fileExtensions: ["md", "gen", "smd", "32x"], layoutID: "genesis",
                      coreStatus: .available(coreID: GenesisPlusGXSpec.coreID)),
        SystemProfile(id: .nintendo64, displayName: "Nintendo 64", shortName: "N64",
                      fileExtensions: ["n64", "z64", "v64"], layoutID: "n64",
                      coreStatus: .notYet(note: "Delta's core is selected; needs the JIT service.")),
        SystemProfile(id: .playStation, displayName: "PlayStation", shortName: "PS1",
                      fileExtensions: ["cue", "chd", "pbp", "ecm", "img"], layoutID: "ps",
                      coreStatus: .notYet(note: "Folium's Mandarine core is selected; not yet ported.")),
        SystemProfile(id: .nintendoDS, displayName: "Nintendo DS", shortName: "DS",
                      fileExtensions: ["nds", "dsi"], layoutID: "nes",
                      coreStatus: .notYet(note: "Folium's Grape core is selected; needs dual-screen surfaces.")),
        SystemProfile(id: .gameCube, displayName: "Nintendo GameCube", shortName: "GameCube",
                      fileExtensions: ["gcm", "gcz", "rvz", "iso"], layoutID: "gc",
                      coreStatus: .notYet(note: "dolphin-ios is selected; needs the Metal backend and the JIT service.")),
        SystemProfile(id: .wii, displayName: "Nintendo Wii", shortName: "Wii",
                      fileExtensions: ["wbfs", "wad"], layoutID: "wiiu",
                      coreStatus: .notYet(note: "dolphin-ios is selected; needs the Metal backend and the JIT service.")),
        SystemProfile(id: wiiU, displayName: "Nintendo Wii U", shortName: "Wii U",
                      fileExtensions: ["wux", "wud", "rpx"], layoutID: "wiiu",
                      coreStatus: .notYet(note: "Cemu (muffin) would be the source; integration is on hold at the owner's request.")),
        SystemProfile(id: .psp, displayName: "PlayStation Portable", shortName: "PSP",
                      fileExtensions: ["cso", "prx"], layoutID: "ps",
                      coreStatus: .notYet(note: "PPSSPP is selected; 10 of its files are GPL-2.0-only and must be resolved first.")),
        SystemProfile(id: .playStation2, displayName: "PlayStation 2", shortName: "PS2",
                      fileExtensions: ["gz", "cso2"], layoutID: "ps",
                      coreStatus: .notYet(note: "Play! for HLE BIOS and iPSX2 for the Metal GS; both selected, neither ported.")),
        SystemProfile(id: .switchNX, displayName: "Nintendo Switch", shortName: "Switch",
                      fileExtensions: ["nsp", "xci", "nca"], layoutID: "switch",
                      coreStatus: .notYet(note: "MeloNX is a .NET NativeAOT dylib and can only ever be a plugin. Its licence is unresolved.")),
        SystemProfile(id: .nintendo3DS, displayName: "Nintendo 3DS", shortName: "3DS",
                      fileExtensions: ["3ds", "cia", "cci", "cxi"], layoutID: "switch",
                      coreStatus: .notYet(note: "libretro's Citra core is GPL-2.0-or-later, verified, and its dynarmic JIT is disabled on arm64 (this platform), leaving a plain interpreter -- but it still needs cryptopp and libressl (real crypto libraries for 3DS's AES-encrypted titles, not small utilities) and a forced software-rendering path instead of its default Vulkan pipeline. A materially larger undertaking than any core integrated so far; not attempted.")),
        SystemProfile(id: .colecoVision, displayName: "ColecoVision", shortName: "Coleco",
                      fileExtensions: ["col"], layoutID: "arcade",
                      coreStatus: .notYet(note: "Folium's Cherry core is selected; unique to this collection.")),
        SystemProfile(id: .wonderSwan, displayName: "WonderSwan", shortName: "WonderSwan",
                      fileExtensions: ["ws", "wsc"], layoutID: "nes",
                      coreStatus: .notYet(note: "Folium's Durian core is selected; unique to this collection.")),
        SystemProfile(id: .chip8, displayName: "CHIP-8", shortName: "CHIP-8",
                      fileExtensions: ["ch8", "c8"], layoutID: "nes",
                      coreStatus: .available(coreID: "avalon.chip8")),
    ]

    public static func profile(for system: SystemIdentifier) -> SystemProfile? {
        all.first { $0.id == system }
    }

    /// Systems a file with this extension could belong to, most likely first.
    ///
    /// Returning a list rather than one answer is deliberate: `.iso` is GameCube, PS2 and PSP, and
    /// `.bin` is a raw dump of half the consoles ever made. Guessing silently and being wrong is
    /// worse than letting the player pick.
    public static func profiles(forExtension ext: String) -> [SystemProfile] {
        let needle = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !needle.isEmpty else { return [] }
        if let shared = ambiguous[needle] {
            return shared.compactMap(profile(for:))
        }
        return all.filter { $0.fileExtensions.contains(needle) }
    }

    /// Extensions that genuinely belong to several systems, in the order a player most likely means.
    private static let ambiguous: [String: [SystemIdentifier]] = [
        "iso": [.gameCube, .playStation2, .psp],
        "bin": [.genesis, .playStation],
        "chd": [.playStation, .playStation2, .psp],
        "pbp": [.psp, .playStation],
        "cue": [.playStation, .genesis],
    ]

    /// Every system with a working core. One, today, and the library says so rather than implying more.
    public static var playable: [SystemProfile] { all.filter(\.coreStatus.isAvailable) }
}
