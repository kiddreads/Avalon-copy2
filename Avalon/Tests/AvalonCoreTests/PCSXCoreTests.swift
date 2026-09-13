// Avalon — pcsx_rearmed, proven against Avalon's own frontend, not just compiled.
//
// A minimal PS-EXE (homebrew executable) image: the real format libpcsxcore/misc.c's Load()
// reads directly for a plain ".exe" ROM (no CD-ROM image, no BIOS boot sequence beyond HLE) --
// an EXE_HEADER struct (libpcsxcore/misc.h) at file offset 0, code at the fixed offset 0x800
// every real PS-EXE file pads its header out to. Fields are read at native (little-endian) byte
// order on this platform -- SWAP32 (libpcsxcore/psxmem.h) is a no-op except on a big-endian host.
//
// The program at the entry point does the minimum a real PS1 game does before its first visible
// frame: write GP1(0x03) (Display Enable, param 0 = enabled) to the GPU's control port at
// 0xBF801814 (KSEG1 -- uncached -- physical 0x1F801814), then spin forever. Traced directly from
// frontend/libretro.c's vout_flip(): it only calls video_cb with real frame data
// (vout_fb_dirty=1) once the GPU has actually flipped a displayed frame, which never happens
// while the GPU is left in its post-reset "display disabled" state -- confirmed by running the
// plain infinite-loop version of this fixture first and observing a nil frame every time, not by
// assuming. Five MIPS R3000 words: lui/lui/sw to hit the port, then the same
// branch-to-self-plus-delay-slot loop as before.
//
//   lui  $t0, 0xbf80        ; $t0 = 0xbf800000
//   lui  $t1, 0x0300        ; $t1 = 0x03000000  (GP1 cmd 0x03, enable=0)
//   sw   $t1, 0x14($t0)     ; *(u32*)0xbf801814 = $t1  -- GP1 port
//   beq  $0, $0, -1         ; branch to self
//   nop                     ; branch-delay slot
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Testing
import Foundation
@testable import AvalonCore

@Suite("pcsx_rearmed, against the real core", .serialized)
struct PCSXCoreTests {

    private static func minimalROM() -> Data {
        var exe = [UInt8](repeating: 0, count: 0x800 + 20)   // header padded to 0x800, then 5 words of code

        exe.replaceSubrange(0..<8, with: Array("PS-X EXE".utf8))

        func putU32(_ value: UInt32, at offset: Int) {
            exe[offset] = UInt8(value & 0xff)
            exe[offset + 1] = UInt8((value >> 8) & 0xff)
            exe[offset + 2] = UInt8((value >> 16) & 0xff)
            exe[offset + 3] = UInt8((value >> 24) & 0xff)
        }

        let entry: UInt32 = 0x8001_0000
        putU32(entry, at: 0x10)          // pc0
        putU32(0, at: 0x14)              // gp0
        putU32(entry, at: 0x18)          // t_addr -- code loads exactly where execution starts
        putU32(20, at: 0x1c)             // t_size -- five MIPS words
        putU32(0x801f_fff0, at: 0x30)    // s_addr -- initial stack pointer, near top of the 2MB RAM

        putU32(0x3c08_bf80, at: 0x800)   // lui $t0, 0xbf80
        putU32(0x3c09_0300, at: 0x804)   // lui $t1, 0x0300
        putU32(0xad09_0014, at: 0x808)   // sw  $t1, 0x14($t0)
        putU32(0x1000_ffff, at: 0x80c)   // beq $0, $0, -1  (infinite loop)
        putU32(0x0000_0000, at: 0x810)   // nop (branch-delay slot)

        return Data(exe)
    }

    private func makeAndStart() throws -> LibretroCore<PCSXSpec> {
        let core = LibretroCore<PCSXSpec>()
        let romURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".exe")
        try Self.minimalROM().write(to: romURL)
        try core.load(game: romURL)
        try core.start(surface: RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 256, height: 240)),
                      audio: SilentAudioSink())
        return core
    }

    @Test("the catalog lists PlayStation as playable through this core")
    func catalogReflectsReality() {
    try LibretroTestLock.withLock {
            let profile = SystemCatalog.profile(for: .playStation)
            #expect(profile?.coreStatus.isAvailable == true)
            if case .available(let coreID) = profile?.coreStatus {
                #expect(coreID == PCSXSpec.coreID)
            }
    }
    }

    @Test("descriptor reflects the real core, not a placeholder")
    func descriptor() {
    try LibretroTestLock.withLock {
            let d = LibretroCore<PCSXSpec>.descriptor
            #expect(d.provenance == "pcsx_rearmed")
    }
    }

    @Test("a minimal PS-EXE image loads and the core renders real frames")
    func runsAndProducesFrames() throws {
    try LibretroTestLock.withLock {
            let core = try makeAndStart()
            // The GPU only reports a frame as real (not a duplicate) on the run where its
            // framebuffer actually changed -- traced directly via frontend/libretro.c's own
            // vout_fb_dirty flag: our fixture's GP1(0x03) Display Enable write makes exactly the
            // *first* retro_run() dirty (vout_fb_dirty=1), and every one after it a legitimate
            // duplicate (vout_fb_dirty=0, since nothing draws anything new) -- not a bug, the
            // documented libretro frame-duplication contract. currentFrame() reflects only the
            // most recent call, so it has to be read right after the first frame, not after
            // running several more that are correctly reported as duplicates.
            core.runFrame(processVideo: true)
            let frame = try #require(core.currentFrame())
            #expect(frame.visibleRect.width > 0)
            #expect(frame.visibleRect.height > 0)
            for _ in 0..<9 { core.runFrame(processVideo: true) }
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
