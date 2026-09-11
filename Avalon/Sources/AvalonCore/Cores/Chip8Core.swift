// Avalon — CHIP-8 core, conforming to the real contract.
//
// The value of this file is not CHIP-8. It is that writing it exercised `EmulatorCore` against an
// actual emulator and surfaced what the contract does and does not provide. Anything awkward here
// would be ten times as awkward for Dolphin.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonChip8

public final class Chip8Core: EmulatorCore {
    public static let descriptor = CoreDescriptor(
        id: "avalon.chip8",
        displayName: "CHIP-8",
        version: "1.0",
        system: .chip8,
        screens: [ScreenDescriptor(id: "main",
                                   nativeSize: PixelSize(width: Int(CHIP8_SCREEN_W),
                                                         height: Int(CHIP8_SCREEN_H)),
                                   aspectRatio: 2.0)],
        // A software core: it writes pixels and Avalon's presenter uploads them. Exactly the case
        // the surface contract has to cover as well as the GPU-native one.
        renderingModel: .softwareFramebuffer(format: .rgba8888,
                                             nativeSize: PixelSize(width: Int(CHIP8_SCREEN_W),
                                                                   height: Int(CHIP8_SCREEN_H))),
        frameDuration: 1.0 / 60.0,
        supportedRates: 0.25...8.0,
        gameSaveFileExtension: "c8sav",
        capabilities: [.saveStates, .memoryAccess],
        provenance: nil)   // original to Avalon; nothing was imported for this

    public private(set) var state: CoreState = .stopped

    /// Instructions per frame. 11 is the conventional ~700 Hz.
    public var instructionsPerFrame: Int = 11

    private var machine = chip8_state()
    private var framebuffer: [UInt32]
    private var surface: RenderSurface?
    private var audio: AudioSink?
    private var romLoaded = false
    private var audioPhase: Double = 0

    public init(seed: UInt32 = 0x13579BDF) {
        framebuffer = [UInt32](repeating: 0, count: Int(CHIP8_SCREEN_W * CHIP8_SCREEN_H))
        chip8_reset(&machine, seed)
    }

    // MARK: Lifecycle

    public func load(game: URL) throws {
        guard let data = try? Data(contentsOf: game) else { throw CoreError.gameNotFound(game) }
        try load(rom: [UInt8](data))
    }

    /// Load from memory. Present because tests assemble their own ROMs, and because a real
    /// frontend often already holds the bytes after extracting an archive.
    public func load(rom: [UInt8]) throws {
        chip8_reset(&machine, machine.rng)
        let ok = rom.withUnsafeBufferPointer { chip8_load(&machine, $0.baseAddress, rom.count) }
        guard ok == 0 else {
            throw CoreError.gameNotFound(URL(fileURLWithPath: "<memory>"))
        }
        romLoaded = true
        state = .stopped
    }

    public func start(surface: RenderSurface, audio: AudioSink) throws {
        guard romLoaded else { throw CoreError.gameNotFound(URL(fileURLWithPath: "<none>")) }
        guard state == .stopped else { throw CoreError.invalidTransition(from: state, to: .running) }
        self.surface = surface
        self.audio = audio
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
        state = .stopped
        surface = nil
        audio = nil
    }

    // MARK: Execution

    public func runFrame(processVideo: Bool) {
        guard state == .running else { return }
        chip8_run_frame(&machine, Int32(instructionsPerFrame))
        if processVideo {
            framebuffer.withUnsafeMutableBufferPointer {
                chip8_render_rgba(&machine, $0.baseAddress, 0xFF_FF_FF_FF, 0xFF_00_00_00)
            }
        }
        emitAudio()
    }

    /// CHIP-8's only sound is a square wave while the sound timer runs.
    private func emitAudio() {
        guard let audio else { return }
        let sampleRate = 48000.0
        let frames = Int(sampleRate / 60.0)
        var buf = [Int16](repeating: 0, count: frames * 2)
        if chip8_is_beeping(&machine) != 0 {
            let step = 440.0 * 2 * Double.pi / sampleRate
            for f in 0..<frames {
                let v = Int16(sin(audioPhase) > 0 ? 6000 : -6000)
                buf[f * 2] = v; buf[f * 2 + 1] = v
                audioPhase += step
                if audioPhase > 2 * Double.pi { audioPhase -= 2 * Double.pi }
            }
        } else {
            audioPhase = 0
        }
        buf.withUnsafeBytes { audio.enqueue($0, sampleRate: sampleRate) }
    }

    /// The current frame, for the presenter.
    public func withFrameBuffer<R>(_ body: (FrameBuffer) throws -> R) rethrows -> R {
        try framebuffer.withUnsafeBytes { raw in
            try body(FrameBuffer(base: raw.baseAddress!, format: .rgba8888,
                                 size: PixelSize(width: Int(CHIP8_SCREEN_W),
                                                 height: Int(CHIP8_SCREEN_H))))
        }
    }

    // MARK: Surface

    public func surfaceDidResize(_ surface: RenderSurface) { self.surface = surface }
    public func surfaceDidInvalidate() { surface = nil }

    // MARK: Input

    public func activate(input: Int, value: Double, playerIndex: Int) {
        guard playerIndex == 0, input >= 0, input < Int(CHIP8_KEY_COUNT) else { return }
        withUnsafeMutablePointer(to: &machine.keys) {
            $0.withMemoryRebound(to: UInt8.self, capacity: Int(CHIP8_KEY_COUNT)) {
                $0[input] = value > 0.5 ? 1 : 0
            }
        }
    }

    public func deactivate(input: Int, playerIndex: Int) {
        activate(input: input, value: 0, playerIndex: playerIndex)
    }

    public func resetInputs() {
        withUnsafeMutablePointer(to: &machine.keys) {
            $0.withMemoryRebound(to: UInt8.self, capacity: Int(CHIP8_KEY_COUNT)) {
                for k in 0..<Int(CHIP8_KEY_COUNT) { $0[k] = 0 }
            }
        }
    }

    /// CHIP-8's hex keypad, in the conventional layout.
    public static let inputMap = CoreInputMap(coreID: "avalon.chip8", mapping: [
        .up: 0x5, .down: 0x8, .left: 0x7, .right: 0x9,
        .a: 0x6, .b: 0x4, .x: 0xE, .y: 0x0,
        .start: 0xF, .select: 0xA,
    ])

    // MARK: Persistence

    /// The whole machine is POD, so a save state is a byte copy plus a versioned header.
    /// The header is the part that matters: Delta stamps its states with the core identifier and
    /// version and filters on it (`Delta/Delta/Emulation/GameViewController.swift:1240-1241`), which is how a
    /// core update stops silently loading an incompatible state.
    private static let stateMagic: UInt32 = 0x41_43_38_53   // "AC8S"
    private static let stateVersion: UInt32 = 1

    public func saveState(to url: URL) throws {
        var out = Data()
        withUnsafeBytes(of: Self.stateMagic.littleEndian) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: Self.stateVersion.littleEndian) { out.append(contentsOf: $0) }
        withUnsafeBytes(of: machine) { out.append(contentsOf: $0) }
        try out.write(to: url)
    }

    public func loadState(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let headerSize = MemoryLayout<UInt32>.size * 2
        guard data.count == headerSize + MemoryLayout<chip8_state>.size else {
            throw CoreError.saveStateIncompatible(expected: "\(MemoryLayout<chip8_state>.size) bytes",
                                                  found: "\(max(0, data.count - headerSize)) bytes")
        }
        let magic = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 0, as: UInt32.self) }
        let version = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) }
        guard magic == Self.stateMagic else {
            throw CoreError.saveStateIncompatible(expected: "AC8S", found: "0x\(String(magic, radix: 16))")
        }
        guard version == Self.stateVersion else {
            throw CoreError.saveStateIncompatible(expected: "v\(Self.stateVersion)", found: "v\(version)")
        }
        machine = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: headerSize, as: chip8_state.self) }
        romLoaded = true
    }

    /// CHIP-8 has no battery-backed save; the contract permits saying so.
    public func saveGameSave(to url: URL) throws {}
    public func loadGameSave(from url: URL) throws {}

    public func readMemory(at address: UInt64, count: Int) -> Data? {
        let start = Int(address)
        guard start >= 0, count > 0, start + count <= Int(CHIP8_MEMORY_SIZE) else { return nil }
        return withUnsafeBytes(of: machine.memory) { raw in
            Data(bytes: raw.baseAddress!.advanced(by: start), count: count)
        }
    }

    // MARK: Inspection, for tests and the debugger

    public var programCounter: UInt16 { machine.pc }
    public var registers: [UInt8] { withUnsafeBytes(of: machine.v) { Array($0.bindMemory(to: UInt8.self)) } }
    public var isHalted: Bool { machine.halted != 0 }
    public var isBeeping: Bool { chip8_is_beeping(&machine) != 0 }
    public func pixel(x: Int, y: Int) -> Bool {
        guard x >= 0, x < Int(CHIP8_SCREEN_W), y >= 0, y < Int(CHIP8_SCREEN_H) else { return false }
        return withUnsafeBytes(of: machine.screen) {
            $0.bindMemory(to: UInt8.self)[y * Int(CHIP8_SCREEN_W) + x] != 0
        }
    }
    public var litPixelCount: Int {
        withUnsafeBytes(of: machine.screen) { $0.bindMemory(to: UInt8.self).reduce(0) { $0 + Int($1) } }
    }
}

public extension SystemIdentifier {
    static let chip8: Self = "com.avalon.system.chip8"
}
