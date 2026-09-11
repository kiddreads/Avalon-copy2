// Avalon — frame pacing.
//
// This is one of the few subsystems where nothing in this repository is worth adopting, so it is
// written rather than harvested. What the reconnaissance found:
//
//   • PPSSPP throttles with a fixed-increment accumulator and a 5.5-frame catch-up clamp, with no
//     phase relationship to the display at all (`PPSSPP/Core/HLE/sceDisplay.cpp:413-477`). Its
//     precise-sleep helper degrades to plain `usleep()` on Apple (`Common/TimeUtil.cpp:390`), and
//     `SYSPROP_DISPLAY_REFRESH_RATE` is hardcoded to 60 on iOS (`ios/main.mm:342-344`) so ProMotion
//     is invisible to it. It collects excellent per-frame present telemetry and feeds it back into
//     nothing.
//   • Play! slices on a tick budget (`Play!/Source/PS2VM.cpp:722,754`) with the same lack of phase lock.
//
// Guest rates are also not the round numbers people assume: PS2 and PSP are 59.94 Hz, Game Boy is
// 59.727 Hz, PAL systems are 50. On a 60 Hz panel none of those divide evenly, and on a 120 Hz
// ProMotion panel the right answer is different again. A pacer that assumes 1 guest frame == 1
// display frame is wrong on every one of them.
//
// The policy here is deterministic and clock-injected so it can be tested without a display.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// What the run loop should do for one display vsync.
public enum PacingDecision: Equatable, Sendable {
    /// Run this many guest frames, presenting the last one.
    case run(frames: Int)
    /// Present nothing new; the guest is ahead of the display.
    case repeatLastFrame
    /// The guest fell too far behind to catch up; frames were abandoned to stop a death spiral.
    case dropped(frames: Int)
}

/// Decides how many guest frames to run per display refresh, keeping guest time locked to real time.
public struct FramePacer: Sendable {
    /// Guest frame duration in seconds, e.g. 1/59.94 for PS2.
    public let guestFrameDuration: Double
    /// Display refresh interval in seconds. On ProMotion this changes at runtime.
    public private(set) var displayInterval: Double
    /// How far behind the guest may fall before Avalon abandons frames instead of spiralling.
    /// PPSSPP uses 5.5; the same order of magnitude is right.
    public let maxCatchUpFrames: Double
    /// Emulation rate multiplier — 2.0 is double-speed fast-forward.
    public private(set) var rate: Double

    /// Accumulated guest time owed, in guest frames.
    private var owed: Double = 0

    /// Tolerance when taking the whole part of `owed`.
    ///
    /// Without this, an exactly-divisible case loses a frame to floating-point drift: a 50 Hz guest
    /// over exactly 10 s of 60 Hz vsyncs accumulates to 499.9999999999 and floors to 499. One frame
    /// per 10 s is 6 frames a minute of guest time silently discarded, which is precisely the slow
    /// audio/video desync that is miserable to diagnose later.
    private static let wholeFrameEpsilon = 1e-9

    public init(guestFrameDuration: Double,
                displayInterval: Double = 1.0 / 60.0,
                maxCatchUpFrames: Double = 5.5,
                rate: Double = 1.0) {
        precondition(guestFrameDuration > 0, "guest frame duration must be positive")
        self.guestFrameDuration = guestFrameDuration
        self.displayInterval = max(1.0 / 1000.0, displayInterval)
        self.maxCatchUpFrames = max(1, maxCatchUpFrames)
        self.rate = max(0.05, rate)
    }

    /// Follow the display when it changes — ProMotion ramps between 120, 80 and 60 Hz on its own,
    /// and a pacer that ignores that judders.
    public mutating func displayRefreshDidChange(to interval: Double) {
        displayInterval = max(1.0 / 1000.0, interval)
    }

    public mutating func setRate(_ newRate: Double) { rate = max(0.05, newRate) }

    /// Reset accumulated debt — after a pause, a load state, or a long stall.
    public mutating func resync() { owed = 0 }

    /// Guest frames currently owed. Exposed for diagnostics and tests.
    public var pendingFrames: Double { owed }

    /// Advance by one display refresh and decide what to run.
    ///
    /// `elapsed` is the real time since the previous call. Passing the measured value rather than
    /// assuming `displayInterval` is what makes this robust to a missed vsync.
    public mutating func tick(elapsed: Double? = nil) -> PacingDecision {
        let dt = max(0, elapsed ?? displayInterval)
        owed += (dt * rate) / guestFrameDuration

        if owed > maxCatchUpFrames {
            // Too far behind to recover. Abandon the backlog rather than run a burst that makes the
            // next frame later still — the failure mode PPSSPP's clamp also guards against.
            let abandoned = Int((owed - 1).rounded(.down))
            owed -= Double(abandoned)
            let toRun = Int((owed + Self.wholeFrameEpsilon).rounded(.down))
            owed = max(0, owed - Double(toRun))
            return .dropped(frames: abandoned)
        }

        let whole = Int((owed + Self.wholeFrameEpsilon).rounded(.down))
        guard whole > 0 else { return .repeatLastFrame }
        owed -= Double(whole)
        if owed < 0 { owed = 0 }        // only reachable via the epsilon; never carry a debt of -0.
        return .run(frames: whole)
    }
}
