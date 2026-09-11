import Testing
import Foundation
@testable import AvalonCore

private final class NullSink: AudioSink, @unchecked Sendable {
    var frames = 0
    func enqueue(_ f: UnsafeRawBufferPointer, sampleRate: Double) { frames += f.count / 4 }
}

private func word(_ w: [UInt16]) -> [UInt8] { w.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] } }
private let spinROM = word([0x600A, 0x6105, 0x6200, 0xF229, 0xD015, 0x120A])

private func makeSession(displayInterval: Double = 1.0/60.0)
    throws -> (CoreSession, Chip8Core, NullSink) {
    let core = Chip8Core()
    try core.load(rom: spinROM)
    let sink = NullSink()
    let s = CoreSession(core: core, audio: sink, inputMap: Chip8Core.inputMap,
                        displayInterval: displayInterval,
                        frameProvider: { core.withFrameBuffer { $0 } })
    try s.start(surface: RenderSurface(nativeHandle: nil,
                                       drawableSize: PixelSize(width: 640, height: 320)))
    return (s, core, sink)
}

@Test("A session drives core, pacer and presenter together")
func sessionComposes() throws {
    let (s, core, sink) = try makeSession()
    for _ in 0..<60 { s.advance() }

    #expect(s.framesRun == 60)          // 60 Hz guest on a 60 Hz display
    #expect(s.framesPresented == 60)
    #expect(s.framesDropped == 0)
    #expect(sink.frames > 0, "audio should have flowed")
    #expect(core.litPixelCount == 14)   // the sprite is on screen
    #expect(s.presenter.stagingSize == PixelSize(width: 64, height: 32))
}

@Test("Only the last frame of a catch-up burst is presented")
func burstPresentsOnce() throws {
    // Running four frames of video when three will never be seen is wasted conversion; the
    // contract's processVideo flag exists for exactly this.
    let (s, _, _) = try makeSession()
    let tick = s.advance(elapsed: 4.0 / 60.0)
    #expect(tick.framesRun == 4)
    #expect(tick.didPresent)
    #expect(s.framesPresented == 1, "four frames run, one presented")
}

@Test("A paused session does not advance the core")
func pausedDoesNotAdvance() throws {
    let (s, core, _) = try makeSession()
    s.advance()
    let pc = core.programCounter
    try s.pause()
    for _ in 0..<10 { s.advance() }
    #expect(core.programCounter == pc)
    #expect(s.framesRun == 1)
}

@Test("Resuming does not make the guest sprint to catch up on paused time")
func resumeResyncs() throws {
    // Without a resync on resume, the pacer still owes every frame of wall-clock spent paused and
    // the game fast-forwards through it — a bug users describe as "it skipped ahead".
    let (s, _, _) = try makeSession()
    try s.pause()
    for _ in 0..<120 { s.advance(elapsed: 1.0/60.0) }   // 2 s paused
    try s.resume()
    let tick = s.advance(elapsed: 1.0/60.0)
    #expect(tick.framesRun <= 1, "ran \(tick.framesRun) frames after resume")
    #expect(s.framesDropped == 0)
}

@Test("Input sent to the session reaches the core")
func sessionRoutesInput() throws {
    let core = Chip8Core()
    // Skip if key 6 down, else set V1 = 1.
    try core.load(rom: word([0x6006, 0xE09E, 0x6101, 0x1208]))
    let s = CoreSession(core: core, audio: NullSink(), inputMap: Chip8Core.inputMap,
                        frameProvider: { core.withFrameBuffer { $0 } })
    try s.start(surface: RenderSurface(nativeHandle: nil,
                                       drawableSize: PixelSize(width: 64, height: 32)))

    s.send(InputEvent(control: .a, value: 1, device: .touchOverlay))   // .a -> CHIP-8 key 6
    s.advance()
    #expect(core.registers[1] == 0, "the key was held, so the load should have been skipped")

    s.releaseAllInputs()
    #expect(s.router.activeControls.isEmpty)
}

@Test("A stall drops frames and records it rather than spiralling")
func stallIsRecorded() throws {
    let (s, _, _) = try makeSession()
    s.advance(elapsed: 2.0)       // app was suspended for two seconds
    #expect(s.framesDropped > 50)
    // And the next tick is ordinary again.
    let next = s.advance(elapsed: 1.0/60.0)
    #expect(next.framesRun <= 2)
}

@Test("Rate is clamped to what the core declares it supports")
func rateIsClamped() throws {
    let (s, _, _) = try makeSession()
    s.setRate(1000)                     // core declares 0.25...8.0
    let fast = s.advance(elapsed: 1.0/60.0)
    if case .run(let n) = fast.decision { #expect(n <= 9, "ran \(n) frames at clamped 8x") }
    s.setRate(1.0)
}

@Test("A 120 Hz display changes presentation cadence, not guest speed")
func proMotion() throws {
    let (s, _, _) = try makeSession(displayInterval: 1.0/120.0)
    for _ in 0..<120 { s.advance() }    // 1 s of 120 Hz vsyncs
    #expect(s.framesRun >= 59 && s.framesRun <= 61, "ran \(s.framesRun) guest frames in 1 s")
}

@Test("A stopped session is inert")
func stoppedIsInert() throws {
    let (s, core, _) = try makeSession()
    s.advance()
    s.stop()
    #expect(core.state == .stopped)
    let tick = s.advance()
    #expect(tick.framesRun == 0)
}
