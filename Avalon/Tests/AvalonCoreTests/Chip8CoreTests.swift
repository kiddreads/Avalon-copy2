import Testing
import Foundation
@testable import AvalonCore
import AvalonAudio

// ROMs here are hand-assembled, so nothing copyrighted is needed and every expected pixel can be
// derived by hand. If Avalon's core contract were wrong, these are the tests that would not pass.

private func rom(_ words: [UInt16]) -> [UInt8] {
    words.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
}

/// Draws the built-in font glyph for "0" at (10, 5), then loops forever.
private let drawZeroROM = rom([
    0x600A,   // LD  V0, 10          x
    0x6105,   // LD  V1, 5           y
    0x6200,   // LD  V2, 0           glyph index
    0xF229,   // LD  F, V2           I = font address of "0"
    0xD015,   // DRW V0, V1, 5       draw 5 rows
    0x120A,   // JP  0x20A           spin
])

/// Captures audio the core produces, so the sink half of the contract is exercised too.
private final class CapturingSink: AudioSink, @unchecked Sendable {
    var frames = 0
    var peak: Int16 = 0
    func enqueue(_ f: UnsafeRawBufferPointer, sampleRate: Double) {
        let s = f.bindMemory(to: Int16.self)
        frames += s.count / 2
        for v in s where abs(Int(v)) > abs(Int(peak)) { peak = v }
    }
}

private func started(_ core: Chip8Core, _ sink: AudioSink = CapturingSink()) throws {
    let surface = RenderSurface(nativeHandle: nil,
                                drawableSize: PixelSize(width: 640, height: 320))
    try core.start(surface: surface, audio: sink)
}

@Test("A real ROM loads, executes, and puts the expected pixels on screen")
func drawsExpectedSprite() throws {
    let core = Chip8Core()
    try core.load(rom: drawZeroROM)
    try started(core)

    core.runFrame(processVideo: true)

    // The "0" glyph is F0,90,90,90,F0 — 4+2+2+2+4 = 14 lit pixels.
    #expect(core.litPixelCount == 14, "got \(core.litPixelCount)")
    // Top row: four across at y=5.
    for x in 10...13 { #expect(core.pixel(x: x, y: 5), "missing (\(x),5)") }
    // Middle rows: only the two edges.
    for y in 6...8 {
        #expect(core.pixel(x: 10, y: y)); #expect(core.pixel(x: 13, y: y))
        #expect(!core.pixel(x: 11, y: y)); #expect(!core.pixel(x: 12, y: y))
    }
    for x in 10...13 { #expect(core.pixel(x: x, y: 9)) }
    #expect(!core.isHalted)
}

@Test("Arithmetic and the flag register behave as the hardware does")
func arithmeticFlags() throws {
    let core = Chip8Core()
    // 0xFF + 0x01 must wrap to 0 and set VF; 0x01 - 0x02 must borrow and clear VF.
    try core.load(rom: rom([
        0x60FF,   // LD V0, 0xFF
        0x6101,   // LD V1, 0x01
        0x8014,   // ADD V0, V1  -> V0 = 0x00, VF = 1
        0x6201,   // LD V2, 1
        0x6302,   // LD V3, 2
        0x8235,   // SUB V2, V3  -> V2 = 0xFF, VF = 0
        0x1210,   // spin
    ]))
    try started(core)
    core.runFrame(processVideo: false)

    let v = core.registers
    #expect(v[0] == 0x00, "V0 = \(v[0])")
    #expect(v[2] == 0xFF, "V2 = \(v[2])")
    #expect(v[0xF] == 0, "VF after borrow = \(v[0xF])")
}

@Test("Input routed through Avalon's router reaches the core and changes execution")
func inputDrivesExecution() throws {
    let core = Chip8Core()
    // Skip the next instruction if key 6 is down; otherwise set V0 = 1.
    try core.load(rom: rom([
        0x6006,   // LD  V0, 6
        0xE09E,   // SKP V0        skip if key 6 is pressed
        0x6101,   // LD  V1, 1     (executed only when key 6 is up)
        0x1208,   // spin
    ]))
    try started(core)

    let router = InputRouter(map: Chip8Core.inputMap)
    // Control .a maps to CHIP-8 key 0x6 in this core's map.
    let ev = InputEvent(control: .a, value: 1, device: .touchOverlay)
    let routed = try #require(router.handle(ev))
    #expect(routed.raw == 0x6)
    core.activate(input: routed.raw, value: routed.value, playerIndex: routed.player)

    core.runFrame(processVideo: false)
    #expect(core.registers[1] == 0, "key was held, so V1 should not have been set")

    // Release and re-run from scratch: now the instruction is not skipped.
    let core2 = Chip8Core()
    try core2.load(rom: rom([0x6006, 0xE09E, 0x6101, 0x1208]))
    try started(core2)
    core2.runFrame(processVideo: false)
    #expect(core2.registers[1] == 1, "key was up, so V1 should be 1")
}

@Test("A save state round-trips mid-execution and resumes identically")
func saveStateRoundTrip() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avalon-c8-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("s.c8sav")

    let core = Chip8Core()
    try core.load(rom: drawZeroROM)
    try started(core)
    for _ in 0..<3 { core.runFrame(processVideo: true) }
    let pcAtSave = core.programCounter
    let pixelsAtSave = core.litPixelCount
    try core.saveState(to: url)

    // Diverge: run more frames.
    for _ in 0..<10 { core.runFrame(processVideo: true) }

    // Restore into a *different* instance — the harder case, and the one a frontend actually does.
    let restored = Chip8Core()
    try restored.loadState(from: url)
    try started(restored)
    #expect(restored.programCounter == pcAtSave)
    #expect(restored.litPixelCount == pixelsAtSave)
    #expect(restored.registers == core.registers)   // this ROM spins, so registers are stable
}

@Test("An incompatible save state is refused with a useful error, not loaded")
func incompatibleStateRefused() throws {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("avalon-c8-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("bad.c8sav")
    try Data(repeating: 0xAB, count: 64).write(to: url)

    let core = Chip8Core()
    #expect(throws: (any Error).self) { try core.loadState(from: url) }
}

@Test("Lifecycle transitions are enforced rather than silently ignored")
func lifecycleIsEnforced() throws {
    let core = Chip8Core()
    // Starting without a ROM must fail.
    #expect(throws: (any Error).self) { try started(core) }

    try core.load(rom: drawZeroROM)
    try started(core)
    #expect(core.state == .running)
    #expect(throws: (any Error).self) { try core.resume() }   // already running

    try core.pause()
    #expect(core.state == .paused)
    // A paused core does not advance.
    let before = core.programCounter
    core.runFrame(processVideo: true)
    #expect(core.programCounter == before)

    try core.resume()
    core.runFrame(processVideo: true)
    core.stop()
    #expect(core.state == .stopped)
}

@Test("The core produces audio through the sink when the sound timer runs")
func audioIsProduced() throws {
    let core = Chip8Core()
    try core.load(rom: rom([
        0x603C,   // LD  V0, 60
        0xF018,   // LD  ST, V0    sound timer = 60 -> beeping
        0x1204,   // spin
    ]))
    let sink = CapturingSink()
    try started(core, sink)
    core.runFrame(processVideo: false)

    #expect(core.isBeeping)
    #expect(sink.frames == 800, "one 60 Hz frame at 48 kHz is 800 frames, got \(sink.frames)")
    #expect(abs(Int(sink.peak)) > 1000, "expected an audible square wave")
}

@Test("readMemory exposes guest memory, which is how achievements work core-agnostically")
func memoryAccess() throws {
    let core = Chip8Core()
    try core.load(rom: drawZeroROM)
    // The ROM is loaded at 0x200, so the first two bytes are the first instruction.
    let d = try #require(core.readMemory(at: 0x200, count: 2))
    #expect(d[0] == 0x60 && d[1] == 0x0A)
    // Out-of-range reads are refused rather than reading adjacent memory.
    #expect(core.readMemory(at: 0xFFF, count: 16) == nil)
    #expect(core.readMemory(at: 0x200, count: -1) == nil)
}

@Test("An illegal instruction halts the core instead of faulting the process")
func illegalInstructionHalts() throws {
    let core = Chip8Core()
    try core.load(rom: rom([0x5001]))   // 5xy0 is defined only for n == 0
    try started(core)
    core.runFrame(processVideo: false)
    #expect(core.isHalted)
    // And the process is still alive to assert that.
}
