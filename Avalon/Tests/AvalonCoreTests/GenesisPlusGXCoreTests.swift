// Avalon — Genesis Plus GX, proven against Avalon's own frontend, not just compiled.
//
// A minimal but structurally valid Genesis ROM: the 68000 reset vectors (initial stack pointer,
// initial program counter) plus the header's console-name field, which is all loadrom.c needs to
// detect the console region and start the core running.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

// Serialized deliberately, same reason as LibretroCoreTests: `avalon_libretro_open` enforces one
// active session process-wide, and swift-testing parallelizes within a suite by default.
@Suite("Genesis Plus GX, against the real core", .serialized)
struct GenesisPlusGXCoreTests {

    private static func minimalROM() -> Data {
        var rom = [UInt8](repeating: 0, count: 0x400)
        rom[0] = 0x00; rom[1] = 0xFF; rom[2] = 0x00; rom[3] = 0x00   // initial SP = 0x00FF0000
        rom[4] = 0x00; rom[5] = 0x00; rom[6] = 0x02; rom[7] = 0x00   // initial PC = 0x000200
        for (i, b) in Array("SEGA GENESIS   ".utf8).enumerated() { rom[0x100 + i] = b }
        return Data(rom)
    }

    private func makeAndStart() throws -> LibretroCore<GenesisPlusGXSpec> {
        let core = LibretroCore<GenesisPlusGXSpec>()
        let romURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try Self.minimalROM().write(to: romURL)
        try core.load(game: romURL)
        try core.start(surface: RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 320, height: 224)),
                      audio: SilentAudioSink())
        return core
    }

    @Test("the catalog lists Genesis as playable through this core")
    func catalogReflectsReality() {
    try LibretroTestLock.withLock {
            let profile = SystemCatalog.profile(for: .genesis)
            #expect(profile?.coreStatus.isAvailable == true)
            if case .available(let id) = profile?.coreStatus {
                #expect(id == GenesisPlusGXSpec.coreID)
            }
    }
    }

    @Test("descriptor reflects the real core, not a placeholder")
    func descriptor() {
    try LibretroTestLock.withLock {
            let d = LibretroCore<GenesisPlusGXSpec>.descriptor
            #expect(d.system == .genesis)
            #expect(d.provenance == "genesis-plus-gx")
    }
    }

    @Test("a minimal ROM loads and the core renders real frames")
    func runsAndProducesFrames() throws {
    try LibretroTestLock.withLock {
            let core = try makeAndStart()
            for _ in 0..<10 { core.runFrame(processVideo: true) }
            let frame = try #require(core.currentFrame())
            #expect(frame.visibleRect.width > 0)
            #expect(frame.visibleRect.height > 0)
            core.stop()
    }
    }

    @Test("save state round-trips through the real serialize ABI")
    func saveStateRoundTrips() throws {
    try LibretroTestLock.withLock {
            let core = try makeAndStart()
            for _ in 0..<5 { core.runFrame(processVideo: true) }

            let saveURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try core.saveState(to: saveURL)
            defer { try? FileManager.default.removeItem(at: saveURL) }
            #expect((try? Data(contentsOf: saveURL))?.isEmpty == false)

            for _ in 0..<20 { core.runFrame(processVideo: true) }   // diverge
            try core.loadState(from: saveURL)   // must not throw / reject a state this core just wrote
            core.stop()
    }
    }
}

private final class SilentAudioSink: AudioSink, @unchecked Sendable {
    func enqueue(_ frames: UnsafeRawBufferPointer, sampleRate: Double) {}
}
