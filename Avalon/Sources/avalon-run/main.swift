// Avalon — headless demonstration.
//
// Runs a real ROM through the whole stack and prints the framebuffer, so "it works" is something
// you can see rather than something the tests assert privately.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import AvalonCore
import AvalonAudio

final class MixerSink: AudioSink, @unchecked Sendable {
    private let mixer = avalon_mixer_create(48000, 48000, 8)!
    var framesPushed = 0
    deinit { avalon_mixer_destroy(mixer) }
    func enqueue(_ f: UnsafeRawBufferPointer, sampleRate: Double) {
        let s = f.bindMemory(to: Int16.self)
        framesPushed += avalon_mixer_push_s16(mixer, s.baseAddress!, s.count / 2)
    }
    var queued: Int { avalon_mixer_queued_frames(mixer) }
}

// A ROM that draws "AVALON" using the built-in hex font glyphs A, 0, 0, 1, 0, 0
// (CHIP-8's font has only 0-F, so this spells what it can).
func word(_ w: [UInt16]) -> [UInt8] { w.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] } }
var program: [UInt16] = [0x6105]                       // V1 = y = 5
for (i, glyph) in [0xA, 0x0, 0xA, 0x1, 0x0, 0xD].enumerated() {
    program.append(0x6000 | UInt16(4 + i * 6))         // V0 = x
    program.append(0x6200 | UInt16(glyph))             // V2 = glyph
    program.append(0xF229)                             // I = font(V2)
    program.append(0xD015)                             // draw 5 rows
}
let spinAt = 0x200 + program.count * 2
program.append(0x1000 | UInt16(spinAt))                // spin

let core = Chip8Core()
try core.load(rom: word(program))

let sink = MixerSink()
let session = CoreSession(core: core, audio: sink, inputMap: Chip8Core.inputMap,
                          displayInterval: 1.0 / 60.0,
                          frameProvider: { core.withFrameBuffer { $0 } })

let surface = RenderSurface(nativeHandle: nil, drawableSize: PixelSize(width: 640, height: 320))
try session.start(surface: surface)

print("Avalon — \(session.descriptor.displayName) \(session.descriptor.version)")
print("JIT mode: \(JITMode.detect())   SIMD presenter: \(FramePresenter.isSIMDAccelerated)")
print("Driving 60 display refreshes at \(String(format: "%.2f", 1 / session.descriptor.frameDuration)) Hz guest…\n")

for _ in 0..<60 { session.advance() }

// Draw what the presenter actually produced, from its BGRA staging buffer.
session.presenter.withStagingBuffer { buf, size in
    print("  ┌" + String(repeating: "─", count: size.width) + "┐")
    for y in 0..<size.height {
        var row = "  │"
        for x in 0..<size.width {
            row += (buf[y * size.width + x] & 0x00FF_FFFF) != 0 ? "█" : " "
        }
        print(row + "│")
    }
    print("  └" + String(repeating: "─", count: size.width) + "┘")
}

print("""

  frames run        \(session.framesRun)
  frames presented  \(session.framesPresented)
  frames dropped    \(session.framesDropped)
  audio frames      \(sink.framesPushed) pushed, \(sink.queued) queued
  core state        \(core.state)  halted=\(core.isHalted)  lit pixels=\(core.litPixelCount)
""")
