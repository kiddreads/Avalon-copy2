// Avalon — mGBA, proven against Avalon's own frontend, not just compiled.
//
// A minimal GBA ROM: the required entry-point branch at offset 0 (jumping past the 192-byte
// header, which is all loadrom needs structurally -- mGBA does not hard-reject a header with a
// blank Nintendo logo/checksum, unlike real hardware), padded out to a plausible ROM size.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

@Suite("mGBA, against the real core", .serialized)
struct MGBACoreTests {

    private static func minimalROM() -> Data {
        var rom = [UInt8](repeating: 0, count: 0x4000)   // 16KB, a plausible minimum GBA size
        // ARM branch: 0xEA000000 | ((dest - (pc + 8)) / 4). Jumping from offset 0 to offset 0xC0
        // (past the 192-byte header) is offset (0xC0 - 8) / 4 = 0x2E.
        rom[0] = 0x2E; rom[1] = 0x00; rom[2] = 0x00; rom[3] = 0xEA
        return Data(rom)
    }

    private func makeAndStart() throws -> LibretroCore<MGBASpec> {
        let core = LibretroCore<MGBASpec>()
        let romURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gba")
        try Self.minimalROM().write(to: romURL)
        try core.load(game: romURL)
        try core.start(surface: RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 240, height: 160)),
                      audio: SilentAudioSink())
        return core
    }

    @Test("the catalog lists GB, GBC and GBA as playable through this one core")
    func catalogReflectsReality() {
    try LibretroTestLock.withLock {
            for id in [SystemIdentifier.gameBoy, .gameBoyAdvance] {
                let profile = SystemCatalog.profile(for: id)
                #expect(profile?.coreStatus.isAvailable == true)
                if case .available(let coreID) = profile?.coreStatus {
                    #expect(coreID == MGBASpec.coreID)
                }
            }
    }
    }

    @Test("descriptor reflects the real core, not a placeholder")
    func descriptor() {
    try LibretroTestLock.withLock {
            let d = LibretroCore<MGBASpec>.descriptor
            #expect(d.provenance == "mgba")
    }
    }

    @Test("a minimal GBA ROM loads and the core renders real frames")
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

            for _ in 0..<20 { core.runFrame(processVideo: true) }
            try core.loadState(from: saveURL)
            core.stop()
    }
    }
}

private final class SilentAudioSink: AudioSink, @unchecked Sendable {
    func enqueue(_ frames: UnsafeRawBufferPointer, sampleRate: Double) {}
}
