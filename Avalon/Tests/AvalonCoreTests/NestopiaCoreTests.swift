// Avalon — Nestopia, proven against Avalon's own frontend, not just compiled.
//
// A minimal but valid iNES ROM: the "NES\x1A" magic, a header declaring 1 PRG bank and 1 CHR
// bank (the smallest legal cartridge), and enough PRG data for the 6502 reset vector at the top
// of the bank to point somewhere inside it. That is all loadrom needs to accept the file and
// start the core running.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

@Suite("Nestopia, against the real core", .serialized)
struct NestopiaCoreTests {

    private static func minimalROM() -> Data {
        var rom = [UInt8]()
        rom += Array("NES\u{1A}".utf8)      // iNES magic
        rom.append(1)                       // 1 x 16KB PRG-ROM bank
        rom.append(1)                       // 1 x 8KB CHR-ROM bank
        // iNES header is exactly 16 bytes: magic(4) + PRG(1) + CHR(1) + flags 6-15(10).
        rom.append(contentsOf: [UInt8](repeating: 0, count: 10))   // flags 6-15, all default/mapper 0
        rom += [UInt8](repeating: 0, count: 16 * 1024)   // PRG bank
        rom += [UInt8](repeating: 0, count: 8 * 1024)    // CHR bank
        // 6502 reset vector, at the very end of the 16KB PRG bank (0xFFFC), points back to the
        // start of the bank -- an infinite loop of zero bytes (BRK), which is a legal, if
        // uninteresting, program.
        let prgStart = 16
        rom[prgStart + 0x3FFC] = 0x00
        rom[prgStart + 0x3FFD] = 0x80
        return Data(rom)
    }

    private func makeAndStart() throws -> LibretroCore<NestopiaSpec> {
        let core = LibretroCore<NestopiaSpec>()
        let romURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".nes")
        try Self.minimalROM().write(to: romURL)
        try core.load(game: romURL)
        try core.start(surface: RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 256, height: 224)),
                      audio: SilentAudioSink())
        return core
    }

    @Test("the catalog lists NES as playable through this core")
    func catalogReflectsReality() {
    try LibretroTestLock.withLock {
            let profile = SystemCatalog.profile(for: .nes)
            #expect(profile?.coreStatus.isAvailable == true)
            if case .available(let id) = profile?.coreStatus {
                #expect(id == NestopiaSpec.coreID)
            }
    }
    }

    @Test("descriptor reflects the real core, not a placeholder")
    func descriptor() {
    try LibretroTestLock.withLock {
            let d = LibretroCore<NestopiaSpec>.descriptor
            #expect(d.system == .nes)
            #expect(d.provenance == "nestopia")
    }
    }

    @Test("a minimal iNES ROM loads and the core renders real frames")
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
