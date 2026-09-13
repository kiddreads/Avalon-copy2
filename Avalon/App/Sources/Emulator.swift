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
/// presenter produced. Nothing here knows what CHIP-8 is beyond choosing it as the core to load.
final class Emulator: ObservableObject {
    @Published private(set) var frame: CGImage?
    @Published private(set) var status: String = "starting"

    private let sink = SilentSink()
    private var session: CoreSession?
    private var core: Chip8Core?
    private var link: CADisplayLink?

    func start() {
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
            // No Metal backend yet, so the core renders into the presenter's staging buffer and
            // this app reads it back. A native surface replaces this without touching the session.
            try session.start(surface: RenderSurface(nativeHandle: nil,
                                                     drawableSize: PixelSize(width: 640, height: 320)))
        } catch {
            status = "session failed to start: \(error)"
            return
        }

        self.core = core
        self.session = session
        status = "\(session.descriptor.displayName) \(session.descriptor.version)"

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        session?.stop()
        session = nil
        core = nil
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
