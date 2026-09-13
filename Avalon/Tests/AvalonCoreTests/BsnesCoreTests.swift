// Avalon — bsnes, proven against Avalon's own frontend, not just compiled.
//
// A minimal 32KB LoROM image satisfying Heuristics::SuperFamicom::scoreHeader, the real detector
// bsnes's own loadSuperFamicom() runs before any cartridge gets built (see
// heuristics/super-famicom.cpp in the vendored source): map mode 0x20 (LoROM, matching the
// $7fb0 header address the scorer checks first) at header+0x25, a checksum/complement pair that
// sums to 0xffff at +0x2e/+0x2c, a reset vector >= 0x8000 at +0x4c, and a "most likely" 65816
// opcode (SEI, 0x78) at the byte the reset vector actually points to. HiROM/ExLoROM/ExHiROM all
// score 0 outright against an image this small (each needs size >= its own header address + 0x50,
// far past 32KB), so LoROM wins the comparison by default once it scores above zero at all.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

@Suite("bsnes, against the real core", .serialized)
struct BsnesCoreTests {

    private static func minimalROM() -> Data {
        var rom = [UInt8](repeating: 0, count: 0x8000)   // 32KB, the smallest scoreHeader accepts
        let header = 0x7fb0

        rom[0] = 0x78                                   // SEI at the reset vector's target (0x0000)
        rom[header + 0x25] = 0x20                        // mapMode: LoROM, matches header address

        let checksum: UInt16 = 0x1234
        let complement: UInt16 = checksum ^ 0xffff        // checksum + complement must equal 0xffff
        rom[header + 0x2c] = UInt8(complement & 0xff)
        rom[header + 0x2d] = UInt8(complement >> 8)
        rom[header + 0x2e] = UInt8(checksum & 0xff)
        rom[header + 0x2f] = UInt8(checksum >> 8)

        let resetVector: UInt16 = 0x8000                  // >= 0x8000, and & 0x7fff == 0 -> byte[0]
        rom[header + 0x4c] = UInt8(resetVector & 0xff)
        rom[header + 0x4d] = UInt8(resetVector >> 8)

        return Data(rom)
    }

    private func makeAndStart() throws -> LibretroCore<BsnesSpec> {
        let core = LibretroCore<BsnesSpec>()
        let romURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sfc")
        try Self.minimalROM().write(to: romURL)
        try core.load(game: romURL)
        try core.start(surface: RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 512, height: 448)),
                      audio: SilentAudioSink())
        return core
    }

    @Test("the catalog lists SNES as playable through this core")
    func catalogReflectsReality() {
    try LibretroTestLock.withLock {
            let profile = SystemCatalog.profile(for: .snes)
            #expect(profile?.coreStatus.isAvailable == true)
            if case .available(let coreID) = profile?.coreStatus {
                #expect(coreID == BsnesSpec.coreID)
            }
    }
    }

    @Test("descriptor reflects the real core, not a placeholder")
    func descriptor() {
    try LibretroTestLock.withLock {
            let d = LibretroCore<BsnesSpec>.descriptor
            #expect(d.provenance == "bsnes")
    }
    }

    @Test("a minimal LoROM image loads and the core renders real frames")
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
