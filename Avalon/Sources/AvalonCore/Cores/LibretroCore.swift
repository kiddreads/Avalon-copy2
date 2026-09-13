// Avalon — hosting a libretro core through EmulatorCore.
//
// libretro cores are statically linked per-core with namespaced symbols (see AvalonLibretro.h for
// why: no dylibs on iOS, and one process can only host one set of bare `retro_*` exports at a
// time). That means `EmulatorCore.descriptor` — a static property, known before any instance
// exists — cannot come from an instance; it has to come from a TYPE. `LibretroCoreSpec` is that
// type: one tiny conforming type per compiled-in core, naming its vtable and its Avalon identity.
// `LibretroCore<Spec>` then implements the contract once, generically, for every core that
// provides one.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonLibretro

/// What one statically-linked libretro core needs to say about itself to appear in Avalon.
public protocol LibretroCoreSpec {
    /// The core's namespaced vtable — e.g. `mgba_libretro_vtable()` for a core built with every
    /// `retro_*` symbol renamed to `mgba_retro_*` and collected here.
    static func vtable() -> UnsafePointer<avalon_libretro_vtable>
    static var coreID: String { get }
    static var displayName: String { get }
    static var version: String { get }
    static var system: SystemIdentifier { get }
    /// A reasonable size to allocate before the real ROM geometry is known. libretro reports the
    /// authoritative width/height only after `load_game`, so this is a starting point, not a promise.
    static var nominalSize: PixelSize { get }
    static var provenance: String? { get }
}

public extension LibretroCoreSpec {
    static var provenance: String? { nil }
}

private func pixelFormat(from f: retro_pixel_format) -> PixelFormat {
    switch f {
    case RETRO_PIXEL_FORMAT_RGB565: return .rgb565
    case RETRO_PIXEL_FORMAT_XRGB8888: return .bgra8888   // native-endian XRGB8888 is B,G,R,X in memory
    default: return .abgr1555   // RETRO_PIXEL_FORMAT_0RGB1555; the C shim already swaps R/B for this
    }
}

/// A libretro core hosted through Avalon's contract. One instance is one running game; the process
/// may only have one `LibretroCore` of any spec alive at a time (`avalon_libretro_open` enforces
/// this and returns nil for a second), which mirrors libretro's own single-active-core reality.
public final class LibretroCore<Spec: LibretroCoreSpec>: EmulatorCore {
    public static var descriptor: CoreDescriptor {
        CoreDescriptor(
            id: Spec.coreID,
            displayName: Spec.displayName,
            version: Spec.version,
            system: Spec.system,
            screens: [ScreenDescriptor(id: "main", nativeSize: Spec.nominalSize)],
            renderingModel: .softwareFramebuffer(format: .bgra8888, nativeSize: Spec.nominalSize),
            frameDuration: 1.0 / 60.0,   // corrected to the real fps once the core reports it
            gameSaveFileExtension: "srm",
            capabilities: [.saveStates, .memoryAccess],
            provenance: Spec.provenance)
    }

    public private(set) var state: CoreState = .stopped

    // avalon_libretro_session is an incomplete C type, so the Clang importer represents any
    // pointer to it as a plain OpaquePointer -- there is no nameable Swift struct to unsafeBitCast
    // through. Pass this straight to every avalon_libretro_* call; do not wrap it.
    private var session: OpaquePointer?
    private var audio: AudioSink?
    private var pendingROMData: Data?
    private var pendingROMPath: String?

    public init() {}

    deinit { stop() }

    // MARK: Lifecycle

    public func load(game url: URL) throws {
        guard let data = try? Data(contentsOf: url) else { throw CoreError.gameNotFound(url) }
        pendingROMData = data
        pendingROMPath = url.path
    }

    public func start(surface: RenderSurface, audio: AudioSink) throws {
        guard state == .stopped else { throw CoreError.invalidTransition(from: state, to: .running) }
        guard let data = pendingROMData else { throw CoreError.gameNotFound(URL(fileURLWithPath: "")) }

        // `Spec.vtable()` points at the core's own static, process-lifetime vtable struct.
        // `avalon_libretro_open` stores this pointer and dereferences it for the whole session
        // (`s->v = vtable` in AvalonLibretro.c), so it must be the real pointer, not a copy —
        // an earlier version routed it through `withUnsafePointer(to: Spec.vtable().pointee)`,
        // which took the address of a STACK COPY that only lived for that one call, and every
        // later `avalon_libretro_run` dereferenced a dangling frame. SIGBUS on the first frame.
        let systemDir = FileManager.default.temporaryDirectory.path
        guard let handle = avalon_libretro_open(Spec.vtable(), systemDir, systemDir) else {
            throw CoreError.invalidTransition(from: state, to: .running)
        }

        let loaded = data.withUnsafeBytes { bytes -> Bool in
            (pendingROMPath ?? "").withCString { path in
                avalon_libretro_load(handle, path, bytes.baseAddress, bytes.count)
            }
        }
        guard loaded else {
            avalon_libretro_close(handle)
            throw CoreError.gameNotFound(URL(fileURLWithPath: pendingROMPath ?? ""))
        }

        self.session = handle
        self.audio = audio
        pendingROMData = nil
        state = .running
    }

    public func pause() throws {
        guard state == .running else { throw CoreError.invalidTransition(from: state, to: .paused) }
        state = .paused
    }

    public func resume() throws {
        guard state == .paused else { throw CoreError.invalidTransition(from: state, to: .running) }
        state = .running
    }

    public func stop() {
        if let session { avalon_libretro_close(session) }
        session = nil
        audio = nil
        audioBox?.release()
        audioBox = nil
        state = .stopped
    }

    public func runFrame(processVideo: Bool) {
        guard state == .running, let session else { return }

        if let audio, audioBox == nil {
            audioBox = Unmanaged.passRetained(AnyAudioSinkBox(sink: audio, session: session))
            avalon_libretro_set_audio(session, { ctx, frames, count in
                guard let ctx, let frames else { return }
                let box = Unmanaged<AnyAudioSinkBox>.fromOpaque(ctx).takeUnretainedValue()
                frames.withMemoryRebound(to: UInt8.self, capacity: count * 4) { bytes in
                    box.sink.enqueue(UnsafeRawBufferPointer(start: bytes, count: count * 4),
                                    sampleRate: avalon_libretro_sample_rate(box.session))
                }
            }, audioBox!.toOpaque())
        }

        avalon_libretro_run(session)
    }

    /// Boxes the audio sink so it can cross the C callback boundary as a raw context pointer.
    /// Retained explicitly (not `lazy`) because the callback fires from C, outside ARC's view.
    private var audioBox: Unmanaged<AnyAudioSinkBox>?

    // MARK: Surface

    public func surfaceDidResize(_ surface: RenderSurface) {}

    /// The frame the core most recently produced, in the shape `CoreSession`'s `frameProvider`
    /// expects. `nil` while nothing has run yet, or when the core reported "same as last frame".
    public func currentFrame() -> FrameBuffer? {
        guard let session else { return nil }
        var raw = avalon_libretro_frame()
        guard avalon_libretro_last_frame(session, &raw), raw.frame_was_duped == 0,
              let pixels = raw.pixels else { return nil }
        let format = pixelFormat(from: raw.format)
        let bytesPerPixel = format.bytesPerPixel
        let strideInPixels = bytesPerPixel > 0 ? raw.pitch / bytesPerPixel : Int(raw.width)
        return FrameBuffer(base: pixels, format: format, sourceStride: strideInPixels,
                           visibleRect: (0, 0, Int(raw.width), Int(raw.height)))
    }

    // MARK: Input

    public func activate(input: Int, value: Double, playerIndex: Int) {
        guard let session else { return }
        avalon_libretro_set_button(session, UInt32(playerIndex), UInt32(input), value > 0.5)
    }

    public func deactivate(input: Int, playerIndex: Int) {
        guard let session else { return }
        avalon_libretro_set_button(session, UInt32(playerIndex), UInt32(input), false)
    }

    public func resetInputs() {
        guard let session else { return }
        avalon_libretro_clear_input(session)
    }

    // MARK: Persistence

    public func saveState(to url: URL) throws {
        guard let session else { throw CoreError.invalidTransition(from: state, to: state) }
        let size = avalon_libretro_serialize_size(session)
        guard size > 0 else { throw CoreError.saveStateIncompatible(expected: "libretro", found: "no serialize support") }
        var buffer = Data(count: size)
        let ok = buffer.withUnsafeMutableBytes { avalon_libretro_serialize(session, $0.baseAddress, size) }
        guard ok else { throw CoreError.saveStateIncompatible(expected: "libretro", found: "serialize failed") }
        try buffer.write(to: url, options: [.atomic])
    }

    public func loadState(from url: URL) throws {
        guard let session else { throw CoreError.invalidTransition(from: state, to: state) }
        let data = try Data(contentsOf: url)
        let ok = data.withUnsafeBytes { avalon_libretro_unserialize(session, $0.baseAddress, data.count) }
        guard ok else { throw CoreError.saveStateIncompatible(expected: "libretro save state", found: "rejected by core") }
    }

    public func saveGameSave(to url: URL) throws {
        guard let session else { return }
        var size: Int = 0
        guard let sram = avalon_libretro_sram(session, &size), size > 0 else { return }
        try Data(bytes: sram, count: size).write(to: url, options: [.atomic])
    }

    public func loadGameSave(from url: URL) throws {
        guard let session, let data = try? Data(contentsOf: url) else { return }
        var size: Int = 0
        guard let sram = avalon_libretro_sram(session, &size), size > 0 else { return }
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            memcpy(sram, base, min(size, data.count))
        }
    }

    public func readMemory(at address: UInt64, count: Int) -> Data? {
        guard let session else { return nil }
        var size: Int = 0
        guard let sram = avalon_libretro_sram(session, &size), address < UInt64(size) else { return nil }
        let n = min(count, size - Int(address))
        guard n > 0 else { return nil }
        return Data(bytes: sram.advanced(by: Int(address)), count: n)
    }
}

/// Carries an `AudioSink` (and the session it belongs to, for the sample rate) across the C
/// callback boundary as an unmanaged context pointer.
private final class AnyAudioSinkBox {
    let sink: AudioSink
    let session: OpaquePointer
    init(sink: AudioSink, session: OpaquePointer) { self.sink = sink; self.session = session }
}
