// Avalon — the core contract.
//
// The lifecycle / input / state / cheat half of this is Delta's `EmulatorBridging`, which is small,
// complete, and proven across seven shipping cores. It was recovered verbatim from Manic EMU's
// conformances (`Manic EMU/Manic EMU/ManicEmu/ManicEmu/Sources/Tools/Cores/EmulatorBridgingBase.swift:9-79`) because DeltaCore itself is an
// unchecked-out submodule.
//
// Three things are deliberately different:
//   1. Video is surface-negotiated, not buffer-returning — see RenderSurface.swift for why.
//   2. Cores are instantiable. Delta and Manic both use process-wide singletons
//      (`FDSEmulatorBridge.shared`, `LibretroCore.sharedInstance()`), which caps them at one instance
//      per core and forecloses local multiplayer, comparison views and preview cores.
//   3. Code memory is requested from Avalon, never mapped by the core — see JITService.swift.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// Static facts about a core, known before it is instantiated.
public struct CoreDescriptor: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let version: String
    public let system: SystemIdentifier
    public let screens: [ScreenDescriptor]
    public let renderingModel: RenderingModel
    /// Nominal frame duration in seconds. Delta carries this as `frameDuration`.
    public let frameDuration: TimeInterval
    /// Emulation rates the core tolerates, for fast-forward and slow-motion.
    public let supportedRates: ClosedRange<Double>
    /// Extension used for the game's own battery save, e.g. `"srm"`.
    public let gameSaveFileExtension: String
    public let capabilities: CoreCapabilities
    /// Which source project this core is derived from — keys into `ProjectRegistry`.
    public let provenance: String?

    public init(id: String, displayName: String, version: String, system: SystemIdentifier,
                screens: [ScreenDescriptor], renderingModel: RenderingModel,
                frameDuration: TimeInterval, supportedRates: ClosedRange<Double> = 1.0...4.0,
                gameSaveFileExtension: String = "srm",
                capabilities: CoreCapabilities = [], provenance: String? = nil) {
        self.id = id; self.displayName = displayName; self.version = version
        self.system = system; self.screens = screens; self.renderingModel = renderingModel
        self.frameDuration = frameDuration; self.supportedRates = supportedRates
        self.gameSaveFileExtension = gameSaveFileExtension
        self.capabilities = capabilities; self.provenance = provenance
    }

    public var nominalFrameRate: Double { frameDuration > 0 ? 1 / frameDuration : 0 }
}

/// Optional abilities, so the frontend can hide what a core cannot do rather than fail at runtime.
public struct CoreCapabilities: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let saveStates     = Self(rawValue: 1 << 0)
    public static let cheats         = Self(rawValue: 1 << 1)
    /// Exposes guest memory — this is how Delta drives RetroAchievements core-agnostically
    /// (`Delta/Delta/RetroAchievements/AchievementsTracker.swift:181`).
    public static let memoryAccess   = Self(rawValue: 1 << 2)
    public static let rewind         = Self(rawValue: 1 << 3)
    /// Needs executable memory. Avalon must provision it before `start` — see JITService.
    public static let requiresJIT    = Self(rawValue: 1 << 4)
    /// Runs, but much slower, without JIT. Fin ships Dolphin this way (`Fin/Readme.md`).
    public static let jitOptional    = Self(rawValue: 1 << 5)
    public static let resolutionScaling = Self(rawValue: 1 << 6)
    /// Needs system files the user must supply (a BIOS dump, keys, firmware).
    ///
    /// Notably false for Play!, whose HLE BIOS removes the requirement entirely
    /// (`Play!/Source/ee/PS2OS.cpp`, `Play!/Source/iop/IopBios.cpp`) — unlike PCSX2/iPSX2.
    public static let requiresSystemFiles = Self(rawValue: 1 << 7)
}

/// What a core is doing. Delta exposes the same idea as a KVO-observable `state`.
public enum CoreState: String, Sendable, Equatable {
    case stopped, preparing, running, paused
}

public enum CoreError: Error, Equatable {
    case gameNotFound(URL)
    case unsupportedSystem(SystemIdentifier)
    case missingSystemFiles([String])
    case surfaceRequired
    case jitUnavailable(reason: String)
    case saveStateIncompatible(expected: String, found: String)
    case invalidCheat(code: String)
    case invalidTransition(from: CoreState, to: CoreState)
}

/// Where a core sends audio. Avalon owns the mixer and the output device.
public protocol AudioSink: AnyObject, Sendable {
    /// Interleaved stereo signed 16-bit at `sampleRate`.
    func enqueue(_ frames: UnsafeRawBufferPointer, sampleRate: Double)
}

/// A core that has been handed a surface and can be driven frame by frame.
///
/// Implementations are expected to be classes owning a C++ or dylib-backed engine.
public protocol EmulatorCore: AnyObject {
    static var descriptor: CoreDescriptor { get }
    var state: CoreState { get }

    // Lifecycle
    func load(game: URL) throws
    func start(surface: RenderSurface, audio: AudioSink) throws
    func pause() throws
    func resume() throws
    func stop()

    /// Advance one frame. `processVideo: false` is how Delta implements fast-forward without
    /// paying for frames nobody will see (`runFrame(processVideo:)`).
    func runFrame(processVideo: Bool)

    // Surface negotiation — the part Delta's contract lacked.
    func surfaceDidResize(_ surface: RenderSurface)
    func surfaceDidInvalidate()

    // Input
    func activate(input: Int, value: Double, playerIndex: Int)
    func deactivate(input: Int, playerIndex: Int)
    func resetInputs()

    // Persistence
    func saveState(to url: URL) throws
    func loadState(from url: URL) throws
    func saveGameSave(to url: URL) throws
    func loadGameSave(from url: URL) throws

    // Optional
    func addCheat(code: String, type: String) throws
    func resetCheats()
    func readMemory(at address: UInt64, count: Int) -> Data?
}

public extension EmulatorCore {
    // Defaults so a core need only implement what it actually supports.
    func addCheat(code: String, type: String) throws { throw CoreError.invalidCheat(code: code) }
    func resetCheats() {}
    func readMemory(at address: UInt64, count: Int) -> Data? { nil }
    func surfaceDidInvalidate() {}
    var descriptor: CoreDescriptor { Self.descriptor }
}
