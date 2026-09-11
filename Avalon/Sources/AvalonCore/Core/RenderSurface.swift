// Avalon — the surface contract.
//
// This is the file that exists because of the single strongest finding in the reconnaissance: five
// independent projects in this repository all ended up handing their core an opaque `CAMetalLayer`
// pointer, and the one project that did *not* provide a surface channel (Delta) proved unable to
// host a GPU-native core — its own derivative, Manic EMU, had to bypass the protocol to run Citra
// (`Manic EMU/.../Cores/ThreeDS.swift:303-362`).
//
// So Avalon inverts Delta's video layer: a core is *given* a surface, it does not hand back a buffer.
// The CPU-framebuffer case is one implementation of this contract rather than the contract itself.
//
// Nothing here imports Metal, UIKit or QuartzCore. The surface is an opaque handle plus geometry, so
// the contract stays testable off-device and platform code stays isolated (brief §7).
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Pixel layouts a software core can hand Avalon's presenter.
///
/// The set is drawn from what cores in this repository actually emit: RGB565 (Delta's NES descriptor,
/// `Cores/FDS.swift:78`), BGRA8 (Delta's 3DS descriptor, `Cores/ThreeDS.swift:158`), and the
/// 16-bit PS1 VRAM formats Folium's Mandarine converts per frame.
public enum PixelFormat: String, Codable, Sendable, CaseIterable {
    case rgb565, rgba8888, bgra8888, abgr1555

    public var bytesPerPixel: Int {
        switch self {
        case .rgb565, .abgr1555: return 2
        case .rgba8888, .bgra8888: return 4
        }
    }
}

public struct PixelSize: Hashable, Codable, Sendable {
    public var width: Int, height: Int
    public init(width: Int, height: Int) { self.width = width; self.height = height }
    public var isEmpty: Bool { width <= 0 || height <= 0 }
    public var pixelCount: Int { max(0, width) * max(0, height) }
}

/// How a core produces pixels. Avalon presents both through one Metal presenter.
public enum RenderingModel: Sendable, Equatable {
    /// The core writes pixels into memory; Avalon uploads and presents them.
    /// Replaces the per-frame `CGImage` → `UIImageView` path every software core in Folium uses
    /// (`Folium/.../KiwiController.swift:381-408`), which allocates and converts on the main actor.
    case softwareFramebuffer(format: PixelFormat, nativeSize: PixelSize)

    /// The core renders directly into a surface Avalon provides — via Metal, or via Vulkan on
    /// MoltenVK, which is what Folium's Cytrus, MeloNX and PPSSPP all do.
    case nativeSurface(api: GraphicsAPI)

    public enum GraphicsAPI: String, Codable, Sendable { case metal, vulkanOnMoltenVK, openGLES }
}

/// A drawable Avalon owns and lends to a core.
///
/// `nativeHandle` is the `CAMetalLayer` as an opaque pointer — exactly the shape every project here
/// converged on. It is `nil` in tests and headless use, which is why the contract never dereferences
/// it; only the platform layer does.
public struct RenderSurface: @unchecked Sendable {
    public let nativeHandle: UnsafeMutableRawPointer?
    /// Size in physical pixels, already multiplied by the screen scale.
    public private(set) var drawableSize: PixelSize
    /// Internal resolution multiplier. Delta's contract had no way to express this at all.
    public private(set) var resolutionScale: Double

    public init(nativeHandle: UnsafeMutableRawPointer?,
                drawableSize: PixelSize,
                resolutionScale: Double = 1.0) {
        self.nativeHandle = nativeHandle
        self.drawableSize = drawableSize
        self.resolutionScale = max(0.25, resolutionScale)
    }

    public mutating func resize(to size: PixelSize) { drawableSize = size }
    public mutating func setResolutionScale(_ scale: Double) { resolutionScale = max(0.25, scale) }

    /// The resolution the core should actually render at.
    public var renderSize: PixelSize {
        PixelSize(width: Int((Double(drawableSize.width) * resolutionScale).rounded()),
                  height: Int((Double(drawableSize.height) * resolutionScale).rounded()))
    }
}

/// A screen a system presents. The 3DS and DS have two; everything else here has one.
public struct ScreenDescriptor: Hashable, Codable, Sendable {
    public let id: String
    public let nativeSize: PixelSize
    /// Display aspect ratio, where it differs from `nativeSize` (PS1/PS2 output is anamorphic).
    public let aspectRatio: Double?
    public let isTouchable: Bool

    public init(id: String, nativeSize: PixelSize, aspectRatio: Double? = nil, isTouchable: Bool = false) {
        self.id = id; self.nativeSize = nativeSize
        self.aspectRatio = aspectRatio; self.isTouchable = isTouchable
    }

    public var displayAspectRatio: Double {
        aspectRatio ?? (nativeSize.height > 0 ? Double(nativeSize.width) / Double(nativeSize.height) : 1)
    }
}
