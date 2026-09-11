// Avalon — device capabilities and known driver quirks.
//
// The PATTERN is PPSSPP's (`PPSSPP/Common/GPU/thin3d.h:322-352,583-643`): known driver defects as
// queryable data with names, rather than as `#ifdef`s scattered through the renderer. The
// reconnaissance called that the single most valuable artifact in the file, and it is.
//
// The CONTENT is not PPSSPP's. Its list is Adreno, Mali, PowerVR and Raspberry Pi defects, none of
// which exist on an Apple-only platform; copying them here would be cargo-culting. Every entry
// below was instead found in this repository's own source, where five separate projects had each
// worked around the same Apple behaviour privately and none of them wrote it down anywhere a
// sibling could find it.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// A known behaviour of Apple graphics or the OS that a renderer must accommodate.
public enum GraphicsQuirk: String, Sendable, CaseIterable, Codable {
    /// Apple GPUs are tile-based deferred; a render-target barrier scope is wrong and must be a
    /// texture scope. iPSX2 hit this: `GS/Renderers/Metal/GSDeviceMTL.mm:2014-2021` swaps
    /// `MTLBarrierScopeRenderTargets` for `MTLBarrierScopeTextures` on iOS.
    case tileBasedBarrierScope

    /// Framebuffer fetch is unavailable on the Simulator, though present on device.
    /// `iPSX2/iPSX2/cpp/pcsx2/GS/Renderers/Metal/GSMTLDeviceInfo.mm:208-212`.
    case noFramebufferFetchOnSimulator

    /// `shm_open` is blocked by the iOS sandbox; shared memory must come from `mkstemp` in TMPDIR.
    /// `iPSX2/iPSX2/cpp/pcsx2/GS/GS.cpp:1113-1128`.
    case noPosixSharedMemory

    /// MoltenVK requires vertex attribute descriptions duplicated per binding.
    /// `MeloNX/src/Ryujinx.Graphics.Vulkan/PipelineState.cs:451-467`.
    case moltenVKDuplicateVertexAttributes

    /// Cross-stage buffer bindings are unreliable before iOS 17; bind to all stages.
    /// `MeloNX/src/Ryujinx.Graphics.Vulkan/PipelineLayoutFactory.cs:22,47-52`.
    case crossStageBufferBindingBroken

    /// Fragment output must be specialized rather than left dynamic on MoltenVK.
    /// `MeloNX/src/Ryujinx.Graphics.Vulkan/VulkanRenderer.cs:838-839`.
    case requiresFragmentOutputSpecialization

    /// `D24_S8` does not exist on Apple GPUs; depth/stencil must use `D32F_S8`.
    case noDepth24Stencil8

    /// No 24-bit colour format. RGB8 sources must be expanded to a 32-bit format on upload —
    /// which is why `AvalonPixel` outputs BGRA8888 and never a packed 24-bit layout.
    case no24BitColorFormat

    /// Reading the destination colour belongs in tile memory, not a storage buffer. Play! reached
    /// this twice independently: Vulkan input attachments on mobile
    /// (`Play!/Source/gs/GSH_Vulkan/GSH_VulkanDrawMobile.cpp:486-498,1088-1089`) and
    /// `EXT_shader_framebuffer_fetch` in the GL backend (`GSH_OpenGL_Shader.cpp:139,607-651`).
    case preferTileMemoryForDestinationRead

    /// `VK_MVK_{ios,macos}_surface` are deprecated; use `VK_EXT_metal_surface`.
    /// Play! still requests the old pair at `Source/gs/GSH_Vulkan/GSH_Vulkan.cpp:88-93`.
    case deprecatedMoltenVKSurfaceExtension

    /// Shader compilation is slow enough that permutation count must be actively suppressed.
    case verySlowShaderCompiler

    public var explanation: String {
        switch self {
        case .tileBasedBarrierScope:
            return "Apple GPUs are TBDR: use MTLBarrierScopeTextures, not ...RenderTargets"
        case .noFramebufferFetchOnSimulator:
            return "Framebuffer fetch exists on device but not in the Simulator"
        case .noPosixSharedMemory:
            return "shm_open is sandbox-blocked on iOS; use mkstemp in TMPDIR"
        case .moltenVKDuplicateVertexAttributes:
            return "MoltenVK needs vertex attribute descriptions duplicated per binding"
        case .crossStageBufferBindingBroken:
            return "Bind buffers to all stages; cross-stage binding is unreliable before iOS 17"
        case .requiresFragmentOutputSpecialization:
            return "Specialize fragment output rather than leaving it dynamic"
        case .noDepth24Stencil8:
            return "D24_S8 is unavailable; use D32F_S8"
        case .no24BitColorFormat:
            return "No 24-bit colour format; expand to 32-bit on upload"
        case .preferTileMemoryForDestinationRead:
            return "Read destination colour from tile memory, not a storage buffer"
        case .deprecatedMoltenVKSurfaceExtension:
            return "Use VK_EXT_metal_surface, not VK_MVK_ios_surface"
        case .verySlowShaderCompiler:
            return "Suppress shader permutations; compilation is a bottleneck"
        }
    }
}

/// The set of quirks in force. A bitset in PPSSPP; a `Set` here, since the count is small and
/// readability at the call site matters more than a word of memory.
public struct GraphicsQuirks: Sendable, Equatable {
    private var quirks: Set<GraphicsQuirk>

    public init(_ quirks: Set<GraphicsQuirk> = []) { self.quirks = quirks }

    public func has(_ q: GraphicsQuirk) -> Bool { quirks.contains(q) }
    public mutating func insert(_ q: GraphicsQuirk) { quirks.insert(q) }
    public var all: Set<GraphicsQuirk> { quirks }
    public var isEmpty: Bool { quirks.isEmpty }

    /// What applies to every Apple GPU Avalon targets.
    public static let appleBaseline = GraphicsQuirks([
        .tileBasedBarrierScope,
        .noDepth24Stencil8,
        .no24BitColorFormat,
        .preferTileMemoryForDestinationRead,
    ])

    /// Baseline plus what is true only in the Simulator.
    public static let simulator = GraphicsQuirks(
        appleBaseline.all.union([.noFramebufferFetchOnSimulator]))

    /// Baseline plus the iOS sandbox restriction and, below iOS 17, the binding defect.
    public static func iOS(version: Int, usingMoltenVK: Bool = false) -> GraphicsQuirks {
        var q = appleBaseline
        q.insert(.noPosixSharedMemory)
        if version < 17 { q.insert(.crossStageBufferBindingBroken) }
        if usingMoltenVK {
            q.insert(.moltenVKDuplicateVertexAttributes)
            q.insert(.requiresFragmentOutputSpecialization)
            q.insert(.deprecatedMoltenVKSurfaceExtension)
        }
        return q
    }
}

/// What the device can do, as opposed to what is broken about it.
public struct DeviceCapabilities: Sendable, Equatable {
    public var supportsFramebufferFetch: Bool
    public var supportsMemorylessRenderTargets: Bool
    public var supportsMSAA: Bool
    public var maxTextureSize: Int
    /// Host page size. 16 KB on Apple silicon, and the reason MeloNX cannot use its fast
    /// host-mapped memory path on iOS at all (`ArmProcessContextFactory.cs:78-87` requires <= 4 KB).
    public var hostPageSize: Int
    public var supportsProMotion: Bool
    public var quirks: GraphicsQuirks

    public init(supportsFramebufferFetch: Bool = true,
                supportsMemorylessRenderTargets: Bool = true,
                supportsMSAA: Bool = true,
                maxTextureSize: Int = 16384,
                hostPageSize: Int = 16384,
                supportsProMotion: Bool = false,
                quirks: GraphicsQuirks = .appleBaseline) {
        self.supportsFramebufferFetch = supportsFramebufferFetch
        self.supportsMemorylessRenderTargets = supportsMemorylessRenderTargets
        self.supportsMSAA = supportsMSAA
        self.maxTextureSize = maxTextureSize
        self.hostPageSize = hostPageSize
        self.supportsProMotion = supportsProMotion
        self.quirks = quirks
    }

    /// Whether a guest whose pages are smaller than the host's needs fault-address patching to get
    /// correct write tracking — the technique MeloNX generates a signal handler for
    /// (`ARMeilleure/Signal/NativeSignalHandlerGenerator.cs:264-294`).
    public func requiresSubPageWriteTracking(guestPageSize: Int) -> Bool {
        guestPageSize > 0 && hostPageSize > guestPageSize
    }
}
