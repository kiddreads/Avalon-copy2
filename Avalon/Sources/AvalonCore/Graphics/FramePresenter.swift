// Avalon — the shared frame presenter.
//
// One presenter serves every software core, replacing the per-core, per-frame
// CGImage/UIImage path that each frontend in this repository reimplements. The staging buffer is
// allocated once per geometry change, not once per frame.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonPixel

/// A frame handed over by a software core.
public struct FrameBuffer {
    public let base: UnsafeRawPointer
    public let format: PixelFormat
    /// Full width of the source surface in pixels. For PS1 VRAM this is 1024, not the visible width.
    public let sourceStride: Int
    /// The part of the source actually on screen.
    public let visibleRect: (x: Int, y: Int, width: Int, height: Int)

    public init(base: UnsafeRawPointer, format: PixelFormat, sourceStride: Int,
                visibleRect: (x: Int, y: Int, width: Int, height: Int)) {
        self.base = base; self.format = format
        self.sourceStride = sourceStride; self.visibleRect = visibleRect
    }

    /// Convenience for a core whose buffer is exactly its visible frame.
    public init(base: UnsafeRawPointer, format: PixelFormat, size: PixelSize) {
        self.init(base: base, format: format, sourceStride: size.width,
                  visibleRect: (0, 0, size.width, size.height))
    }
}

public enum PresenterError: Error, Equatable {
    case emptyFrame
    case regionOutOfBounds
    case conversionFailed(Int32)
}

/// Converts core frames into a BGRA8888 staging buffer ready for texture upload.
///
/// Deliberately holds no Metal types so the conversion path is testable off-device; the platform
/// layer owns the `MTLTexture` and calls `withStagingBuffer` to upload.
public final class FramePresenter {
    public private(set) var stagingSize: PixelSize = .init(width: 0, height: 0)
    public private(set) var framesPresented: Int = 0
    /// Whether the conversion took a SIMD path in this build.
    public static var isSIMDAccelerated: Bool { avalon_pixel_simd_enabled() != 0 }

    private var staging: UnsafeMutableBufferPointer<UInt32>?

    public init() {}
    deinit { staging?.deallocate() }

    private func ensureStaging(_ size: PixelSize) {
        guard stagingSize != size else { return }
        staging?.deallocate()
        let count = max(1, size.pixelCount)
        staging = UnsafeMutableBufferPointer<UInt32>.allocate(capacity: count)
        staging?.initialize(repeating: 0)
        stagingSize = size
    }

    /// Convert one frame. Only the visible region is touched — the whole point for cores like
    /// Mandarine whose source surface is many times larger than what is on screen.
    @discardableResult
    public func present(_ frame: FrameBuffer) throws -> PixelSize {
        let (x, y, w, h) = frame.visibleRect
        guard w > 0, h > 0 else { throw PresenterError.emptyFrame }
        guard x >= 0, y >= 0, frame.sourceStride >= x + w else {
            throw PresenterError.regionOutOfBounds
        }
        let size = PixelSize(width: w, height: h)
        ensureStaging(size)
        guard let dst = staging?.baseAddress else { throw PresenterError.emptyFrame }

        let rc = avalon_convert_region(frame.base, frame.sourceStride, dst, w,
                                       x, y, w, h, frame.format.cFormat)
        guard rc == 0 else { throw PresenterError.conversionFailed(rc) }
        framesPresented += 1
        return size
    }

    /// Hand the converted pixels to the platform layer for texture upload.
    public func withStagingBuffer<R>(_ body: (UnsafeBufferPointer<UInt32>, PixelSize) throws -> R) rethrows -> R? {
        guard let s = staging, stagingSize.pixelCount > 0 else { return nil }
        return try body(UnsafeBufferPointer(s), stagingSize)
    }
}

extension PixelFormat {
    var cFormat: avalon_pixel_format {
        switch self {
        case .rgb565: return AVALON_PIXEL_RGB565
        case .abgr1555: return AVALON_PIXEL_ABGR1555
        case .rgba8888: return AVALON_PIXEL_RGBA8888
        case .bgra8888: return AVALON_PIXEL_BGRA8888
        }
    }
}
