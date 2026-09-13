// Avalon — the running core, driven by the display.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import CoreGraphics
import QuartzCore
import Combine
import AvalonCore

/// Audio has no output path on iOS yet — no AVAudioEngine, no ring buffer. The session requires a
/// sink, so it gets one that counts frames and drops them. Counting rather than ignoring means the
/// core's audio production is still observable when the real sink lands.
final class SilentSink: AudioSink, @unchecked Sendable {
    private(set) var framesDropped = 0
    func enqueue(_ frames: UnsafeRawBufferPointer, sampleRate: Double) {
        framesDropped += frames.count / 4
    }
}

/// Owns a core and its session, advances it once per display refresh, and publishes the frame the
/// presenter produced.
///
/// Which concrete core gets built lives in exactly one place — `makeSession(for:)` — keyed off
/// `SystemCatalog`, the same source of truth the library screen reads. A system with no core
/// wired here is a system `SystemCatalog` must also mark `.notYet`; `SystemCatalogTests` in the
/// package enforces that the two never drift apart.
final class Emulator: ObservableObject {
    @Published private(set) var frame: CGImage?
    @Published private(set) var status: String = "starting"

    private let sink = SilentSink()
    private var session: CoreSession?
    private var link: CADisplayLink?

    /// Starts the real game if a core exists for it; otherwise reports why not rather than
    /// silently doing nothing. Callers should check `game.profile?.coreStatus.isAvailable` first
    /// so the UI can show its own "no core yet" state instead of relying on this string.
    func start(game: Game) {
        guard session == nil else { return }
        guard let session = Self.makeSession(for: game, sink: sink) else {
            status = "No core for \(game.profile?.displayName ?? "this system") yet"
            return
        }

        do {
            // No Metal backend yet, so a software core renders into the presenter's staging
            // buffer and this app reads it back. A native surface replaces this without
            // touching the session.
            try session.start(surface: RenderSurface(nativeHandle: nil,
                                                     drawableSize: PixelSize(width: 640, height: 320)))
        } catch {
            status = "session failed to start: \(error)"
            return
        }

        self.session = session
        status = "\(session.descriptor.displayName) \(session.descriptor.version)"

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Also usable without a library entry, for the CHIP-8 built-in demo.
    func startDemo() {
        guard session == nil else { return }
        let core = Chip8Core()
        do {
            try core.load(rom: Self.demoROM())
        } catch {
            status = "ROM failed to load: \(error)"
            return
        }
        let session = CoreSession(core: core, audio: sink, inputMap: Chip8Core.inputMap,
                                  displayInterval: 1.0 / 60.0,
                                  frameProvider: { core.withFrameBuffer { $0 } })
        do {
            try session.start(surface: RenderSurface(nativeHandle: nil,
                                                     drawableSize: PixelSize(width: 640, height: 320)))
        } catch {
            status = "session failed to start: \(error)"
            return
        }
        self.session = session
        status = "\(session.descriptor.displayName) \(session.descriptor.version)"
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// One switch, keyed by system, is the only place a new core gets wired into the app. Returns
    /// nil for anything `SystemCatalog` does not also mark `.available` — the two are asserted to
    /// agree by `SystemCatalogTests.honestAboutCores` in the package, so this can't silently drift
    /// into claiming a system works when the catalog says it doesn't, or vice versa.
    private static func makeSession(for game: Game, sink: AudioSink) -> CoreSession? {
        switch game.system {
        case .chip8:
            let core = Chip8Core()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: Chip8Core.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.withFrameBuffer { $0 } })

        case .genesis:
            let core = LibretroCore<GenesisPlusGXSpec>()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: GenesisPlusGXSpec.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.currentFrame() })

        case .nes:
            let core = LibretroCore<NestopiaSpec>()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: NestopiaSpec.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.currentFrame() })

        case .gameBoy, .gameBoyAdvance:
            let core = LibretroCore<MGBASpec>()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: MGBASpec.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.currentFrame() })

        case .snes:
            let core = LibretroCore<BsnesSpec>()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: BsnesSpec.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.currentFrame() })

        case .playStation:
            let core = LibretroCore<PCSXSpec>()
            guard (try? core.load(game: game.url)) != nil else { return nil }
            return CoreSession(core: core, audio: sink, inputMap: PCSXSpec.inputMap,
                               displayInterval: 1.0 / 60.0,
                               frameProvider: { core.currentFrame() })

        default:
            return nil
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        session?.stop()
        session = nil
    }

    func send(_ events: [InputEvent]) {
        guard let session else { return }
        for event in events { session.send(event) }
    }

    @objc private func step() {
        guard let session else { return }
        _ = session.advance()
        session.presenter.withStagingBuffer { buffer, size in
            frame = Self.image(from: buffer, size: size)
        }
    }

    /// BGRA in a flat buffer is exactly what CGImage wants, given the right byte order.
    private static func image(from buffer: UnsafeBufferPointer<UInt32>, size: PixelSize) -> CGImage? {
        guard let base = buffer.baseAddress, size.width > 0, size.height > 0 else { return nil }
        let byteCount = size.width * size.height * 4
        let data = Data(bytes: base, count: byteCount)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let info = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue
                                        | CGBitmapInfo.byteOrder32Little.rawValue)
        return CGImage(width: size.width, height: size.height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: size.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: info, provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The same program `avalon-run` uses, so the device shows what the terminal shows.
    /// CHIP-8's built-in font is 0-F, so it spells what it can.
    private static func demoROM() -> [UInt8] {
        var program: [UInt16] = [0x6105]
        for (i, glyph) in [0xA, 0x0, 0xA, 0x1, 0x0, 0xD].enumerated() {
            program.append(0x6000 | UInt16(4 + i * 6))
            program.append(0x6200 | UInt16(glyph))
            program.append(0xF229)
            program.append(0xD015)
        }
        program.append(0x1000 | UInt16(0x200 + program.count * 2))
        return program.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
    }
}
