import Testing
import Foundation
@testable import AvalonCore

// Output is BGRA8888 in memory order (B,G,R,A) = MTLPixelFormatBGRA8Unorm.
// As a little-endian UInt32 that is 0xAARRGGBB.

@Test("5- and 6-bit channels are bit-replicated, so full-scale maps to 0xFF")
func rgb565FullScale() throws {
    // Pure white 0xFFFF must become opaque white. Naive shifting gives 0xFFF8FCF8 — visibly dim.
    var src: [UInt16] = [0xFFFF, 0x0000, 0xF800, 0x07E0, 0x001F]
    let presenter = FramePresenter()
    try src.withUnsafeBytes { raw in
        _ = try presenter.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                              size: .init(width: 5, height: 1)))
    }
    presenter.withStagingBuffer { buf, _ in
        #expect(buf[0] == 0xFFFFFFFF)  // white
        #expect(buf[1] == 0xFF000000)  // black, opaque
        #expect(buf[2] == 0xFFFF0000)  // pure red
        #expect(buf[3] == 0xFF00FF00)  // pure green
        #expect(buf[4] == 0xFF0000FF)  // pure blue
    }
}

@Test("ABGR1555 (PS1 VRAM) channel order is honoured")
func abgr1555Channels() throws {
    // bit15 mask, then B(10-14) G(5-9) R(0-4)
    var src: [UInt16] = [0x001F, 0x03E0, 0x7C00, 0x7FFF]
    let p = FramePresenter()
    try src.withUnsafeBytes { raw in
        _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: .abgr1555,
                                      size: .init(width: 4, height: 1)))
    }
    p.withStagingBuffer { buf, _ in
        #expect(buf[0] == 0xFFFF0000)  // red
        #expect(buf[1] == 0xFF00FF00)  // green
        #expect(buf[2] == 0xFF0000FF)  // blue
        #expect(buf[3] == 0xFFFFFFFF)  // white
    }
}

@Test("RGBA8888 swaps R and B and preserves alpha")
func rgbaSwap() throws {
    var src: [UInt32] = [0x80FF8040]  // memory R=0x40 G=0x80 B=0xFF A=0x80
    let p = FramePresenter()
    try src.withUnsafeBytes { raw in
        _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: .rgba8888,
                                      size: .init(width: 1, height: 1)))
    }
    p.withStagingBuffer { buf, _ in
        // memory becomes B=0xFF G=0x80 R=0x40 A=0x80 -> 0x804080FF
        #expect(buf[0] == 0x804080FF)
    }
}

@Test("The SIMD path agrees with the scalar path across the whole 16-bit space")
func simdMatchesScalarExhaustively() throws {
    // 65,536 values is the entire RGB565 and ABGR1555 input space. Vector and tail code both run
    // because the count is not a multiple of the 8-pixel vector width.
    var src = (0...65535).map { UInt16($0) }
    src.append(contentsOf: [0x1234, 0xABCD, 0x0001])  // force a ragged tail
    for fmt in [PixelFormat.rgb565, .abgr1555] {
        let p = FramePresenter()
        try src.withUnsafeBytes { raw in
            _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: fmt,
                                          size: .init(width: src.count, height: 1)))
        }
        p.withStagingBuffer { buf, _ in
            for (i, v) in src.enumerated() {
                let expected: UInt32
                if fmt == .rgb565 {
                    let r5 = UInt32(v >> 11 & 0x1F), g6 = UInt32(v >> 5 & 0x3F), b5 = UInt32(v & 0x1F)
                    expected = 0xFF000000 | ((r5 << 3 | r5 >> 2) << 16)
                                          | ((g6 << 2 | g6 >> 4) << 8) | (b5 << 3 | b5 >> 2)
                } else {
                    let b5 = UInt32(v >> 10 & 0x1F), g5 = UInt32(v >> 5 & 0x1F), r5 = UInt32(v & 0x1F)
                    expected = 0xFF000000 | ((r5 << 3 | r5 >> 2) << 16)
                                          | ((g5 << 3 | g5 >> 2) << 8) | (b5 << 3 | b5 >> 2)
                }
                if buf[i] != expected {
                    Issue.record("\(fmt) mismatch at \(i) (0x\(String(v, radix: 16))): got 0x\(String(buf[i], radix: 16)), want 0x\(String(expected, radix: 16))")
                    return
                }
            }
        }
    }
}

@Test("A region blit reads only the visible window, not the whole surface")
func regionBlitSkipsUnseenPixels() throws {
    // Mandarine's geometry: 1024x512 PS1 VRAM, 320x240 visible.
    // Folium converts all 524,288 pixels then crops; this touches 76,800 — 6.8x less work.
    let vramW = 1024, vramH = 512
    var vram = [UInt16](repeating: 0x0000, count: vramW * vramH)
    // Mark only the visible window so a whole-surface conversion would be detectable.
    for y in 100..<340 { for x in 64..<384 { vram[y * vramW + x] = 0x7FFF } }

    let p = FramePresenter()
    let size = try vram.withUnsafeBytes { raw in
        try p.present(FrameBuffer(base: raw.baseAddress!, format: .abgr1555,
                                  sourceStride: vramW,
                                  visibleRect: (x: 64, y: 100, width: 320, height: 240)))
    }
    #expect(size == PixelSize(width: 320, height: 240))
    p.withStagingBuffer { buf, s in
        #expect(s.pixelCount == 320 * 240)
        #expect(buf.allSatisfy { $0 == 0xFFFFFFFF })   // every visible pixel is white
    }
    #expect(p.framesPresented == 1)
}

@Test("The staging buffer is reallocated on geometry change, not per frame")
func stagingIsStable() throws {
    var src = [UInt16](repeating: 0xFFFF, count: 256 * 240)
    let p = FramePresenter()
    for _ in 0..<10 {
        try src.withUnsafeBytes { raw in
            _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                          size: .init(width: 256, height: 240)))
        }
    }
    #expect(p.stagingSize == PixelSize(width: 256, height: 240))
    #expect(p.framesPresented == 10)
}

@Test("Out-of-bounds regions are refused rather than read past the end")
func boundsAreChecked() throws {
    var src = [UInt16](repeating: 0, count: 64 * 64)
    let p = FramePresenter()
    try src.withUnsafeBytes { raw in
        #expect(throws: PresenterError.regionOutOfBounds) {
            _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                          sourceStride: 64,
                                          visibleRect: (x: 40, y: 0, width: 40, height: 10)))
        }
        #expect(throws: PresenterError.emptyFrame) {
            _ = try p.present(FrameBuffer(base: raw.baseAddress!, format: .rgb565,
                                          sourceStride: 64, visibleRect: (0, 0, 0, 10)))
        }
    }
}
