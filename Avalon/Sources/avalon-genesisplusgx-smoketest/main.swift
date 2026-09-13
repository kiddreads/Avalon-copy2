// Avalon — proving Genesis Plus GX actually runs, not just compiles.
//
// A build succeeding is necessary, not sufficient. This loads a minimal but structurally valid
// Genesis ROM header through the real, namespaced, compiled core and drives it for real frames.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonCore

final class DroppingSink: AudioSink {
    func enqueue(_ frames: UnsafeRawBufferPointer, sampleRate: Double) {}
}

// A minimal Genesis ROM: the 68000 reset vectors (initial SP, initial PC both pointing at
// 0x200, just past the vector table) followed by a couple of harmless NOP-equivalent words,
// padded out. Genesis Plus GX's loadrom.c only requires enough bytes to detect the console
// region and set up memory; it does not require a valid game beyond that to start rendering.
var rom = [UInt8](repeating: 0, count: 0x400)
rom[0] = 0x00; rom[1] = 0xFF; rom[2] = 0x00; rom[3] = 0x00   // initial SP = 0x00FF0000
rom[4] = 0x00; rom[5] = 0x00; rom[6] = 0x02; rom[7] = 0x00   // initial PC = 0x000200
// "SEGA" at the header's console-name field lets the region/TMSS checks succeed cleanly.
let sega = Array("SEGA GENESIS   ".utf8)
for (i, b) in sega.enumerated() { rom[0x100 + i] = b }

let core = LibretroCore<GenesisPlusGXSpec>()
do {
    let romURL = FileManager.default.temporaryDirectory.appendingPathComponent("smoketest.md")
    try Data(rom).write(to: romURL)
    try core.load(game: romURL)
    try core.start(surface: RenderSurface(nativeHandle: nil,
                                          drawableSize: PixelSize(width: 320, height: 224)),
                  audio: DroppingSink())
    print("Genesis Plus GX started: \(LibretroCore<GenesisPlusGXSpec>.descriptor.displayName) " +
          "\(LibretroCore<GenesisPlusGXSpec>.descriptor.version)")

    for i in 0..<10 { core.runFrame(processVideo: true) }

    if let frame = core.currentFrame() {
        print("Frame \(frame.visibleRect.width)x\(frame.visibleRect.height), format \(frame.format)")
        print("PASS: 10 frames executed through the real, compiled, namespaced core.")
    } else {
        print("FAIL: core.currentFrame() returned nil after 10 frames.")
        exit(1)
    }
    core.stop()
} catch {
    print("FAIL: \(error)")
    exit(1)
}
