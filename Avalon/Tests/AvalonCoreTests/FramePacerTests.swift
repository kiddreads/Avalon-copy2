import Testing
import Foundation
@testable import AvalonCore

// Guest rates here are the real ones, not rounded: PS2/PSP 59.94, Game Boy 59.727, PAL 50.

private let ps2 = 1.0 / 59.94
private let gameBoy = 1.0 / 59.7275
private let pal = 1.0 / 50.0

@Test("59.94 Hz guest on a 60 Hz panel stays locked over a full minute")
func ps2OnSixtyHertz() {
    var pacer = FramePacer(guestFrameDuration: ps2, displayInterval: 1.0/60.0)
    var ran = 0
    for _ in 0..<3600 {                       // 60 s of vsyncs
        if case .run(let n) = pacer.tick() { ran += n }
    }
    // 60 s of guest time at 59.94 Hz is 3596.4 frames. Allow the sub-frame remainder.
    #expect(ran >= 3595 && ran <= 3597, "ran \(ran)")
}

@Test("A 50 Hz PAL guest on a 60 Hz panel repeats frames rather than inventing them")
func palOnSixtyHertz() {
    var pacer = FramePacer(guestFrameDuration: pal, displayInterval: 1.0/60.0)
    var ran = 0, repeats = 0
    for _ in 0..<600 {                        // 10 s
        switch pacer.tick() {
        case .run(let n): ran += n
        case .repeatLastFrame: repeats += 1
        case .dropped: Issue.record("should not drop while ahead")
        }
    }
    #expect(ran == 500, "ran \(ran)")          // exactly 10 s at 50 Hz
    #expect(repeats == 100)                    // the other 100 vsyncs show the previous frame
}

@Test("ProMotion: following the display to 120 Hz does not change guest pace")
func proMotionDoesNotAlterGuestRate() {
    // PPSSPP hardcodes 60 Hz on iOS (ios/main.mm:342-344), so it cannot do this at all.
    var pacer = FramePacer(guestFrameDuration: ps2, displayInterval: 1.0/60.0)
    var ran = 0
    for _ in 0..<300 { if case .run(let n) = pacer.tick() { ran += n } }   // 5 s @60
    pacer.displayRefreshDidChange(to: 1.0/120.0)
    for _ in 0..<600 { if case .run(let n) = pacer.tick() { ran += n } }   // 5 s @120
    // 10 s of guest time regardless of panel rate.
    #expect(ran >= 598 && ran <= 600, "ran \(ran)")
}

@Test("Fast-forward multiplies guest frames, not display frames")
func fastForward() {
    var pacer = FramePacer(guestFrameDuration: ps2, displayInterval: 1.0/60.0, rate: 2.0)
    var ran = 0
    for _ in 0..<60 { if case .run(let n) = pacer.tick() { ran += n } }    // 1 s of vsyncs
    #expect(ran >= 119 && ran <= 121, "ran \(ran)")                        // ~2 s of guest time
}

@Test("A long stall drops the backlog instead of spiralling")
func stallDropsRatherThanSpirals() {
    var pacer = FramePacer(guestFrameDuration: ps2, displayInterval: 1.0/60.0)
    // The app was suspended for a second — ~60 guest frames owed.
    let decision = pacer.tick(elapsed: 1.0)
    guard case .dropped(let abandoned) = decision else {
        Issue.record("expected .dropped, got \(decision)"); return
    }
    #expect(abandoned > 50)
    // Crucially, the debt is gone: the next tick is back to normal, not another burst.
    #expect(pacer.pendingFrames < 1.0)
    if case .dropped = pacer.tick() { Issue.record("should have recovered after one drop") }
}

@Test("resync clears debt after a pause or load state")
func resyncClearsDebt() {
    var pacer = FramePacer(guestFrameDuration: gameBoy, displayInterval: 1.0/60.0)
    _ = pacer.tick(elapsed: 0.5)
    pacer.resync()
    #expect(pacer.pendingFrames == 0)
}

@Test("A missed vsync is absorbed using measured elapsed time, not the nominal interval")
func missedVsyncAbsorbed() {
    // A 60 Hz guest on a 60 Hz panel: two elapsed intervals must run two frames.
    var exact = FramePacer(guestFrameDuration: 1.0/60.0, displayInterval: 1.0/60.0)
    guard case .run(let n) = exact.tick(elapsed: 2.0/60.0) else {
        Issue.record("expected to run frames"); return
    }
    #expect(n == 2, "ran \(n)")

    // At 59.94 Hz two 60 Hz intervals are only 1.998 guest frames, so one runs now and the
    // remainder carries — running two would be inventing 0.002 frames of guest time.
    var ntsc = FramePacer(guestFrameDuration: ps2, displayInterval: 1.0/60.0)
    guard case .run(let m) = ntsc.tick(elapsed: 2.0/60.0) else {
        Issue.record("expected to run frames"); return
    }
    #expect(m == 1, "ran \(m)")
    #expect(ntsc.pendingFrames > 0.99 && ntsc.pendingFrames < 1.0)
}
