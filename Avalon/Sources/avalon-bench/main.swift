// Avalon — conversion benchmark. Substantiates the claim in docs/ARCHITECTURE.md.
// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import AvalonCore

func bench(_ name: String, iterations: Int, _ body: () throws -> Void) rethrows {
    try body() // warm
    let t0 = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<iterations { try body() }
    let ns = Double(DispatchTime.now().uptimeNanoseconds - t0) / Double(iterations)
    let padded = name.padding(toLength: 44, withPad: " ", startingAt: 0)
    print("  \(padded) " + String(format: "%8.1f", ns/1000) + " us/frame")
}

print("Avalon frame conversion — SIMD accelerated: \(FramePresenter.isSIMDAccelerated)\n")

// 1. NES-sized RGB565, the common software-core case.
var nes = [UInt16](repeating: 0x1234, count: 256*240)
let p1 = FramePresenter()
print("NES 256x240 RGB565:")
try nes.withUnsafeBytes { raw in
    try bench("Avalon presenter (full frame)", iterations: 2000) {
        _ = try p1.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                       size: .init(width: 256, height: 240)))
    }
}

// 2. The Mandarine case: 1024x512 PS1 VRAM, 320x240 visible.
//    Folium converts the whole surface then crops (MandarineController.swift:340-352).
let vramW = 1024, vramH = 512
var vram = [UInt16](repeating: 0x7FFF, count: vramW*vramH)
let pFull = FramePresenter(), pRegion = FramePresenter()
print("\nPS1 VRAM 1024x512, 320x240 visible:")
try vram.withUnsafeBytes { raw in
    try bench("whole-surface convert, then crop (Folium)", iterations: 500) {
        _ = try pFull.present(FrameBuffer(base: raw.baseAddress!, format: .abgr1555,
                                          size: .init(width: vramW, height: vramH)))
    }
    try bench("region blit only (Avalon)", iterations: 500) {
        _ = try pRegion.present(FrameBuffer(base: raw.baseAddress!, format: .abgr1555,
                                            sourceStride: vramW,
                                            visibleRect: (64, 100, 320, 240)))
    }
}

// 3. GBA-sized, for scale.
var gba = [UInt16](repeating: 0x03E0, count: 240*160)
let p3 = FramePresenter()
print("\nGBA 240x160 RGB565:")
try gba.withUnsafeBytes { raw in
    try bench("Avalon presenter", iterations: 3000) {
        _ = try p3.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                       size: .init(width: 240, height: 160)))
    }
}
