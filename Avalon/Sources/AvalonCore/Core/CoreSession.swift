// Avalon — the run loop.
//
// This is the piece that turns the subsystems into a platform: one object owns a core, the pacer,
// the presenter, the input router and the audio sink, and advances them together. A frontend drives
// `advance(elapsed:)` from a display callback and does nothing else.
//
// It is also where the brief's separation of concerns is enforced in practice. The session knows
// about the core contract and nothing about Metal, UIKit or any specific core; the core knows
// nothing about pacing or presentation. Folium's equivalent is a 7,500-line tree of per-core view
// controllers, each re-implementing this.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// What one advance actually did, for diagnostics and tests.
public struct SessionTick: Equatable, Sendable {
    public let decision: PacingDecision
    public let framesRun: Int
    public let didPresent: Bool
}

public final class CoreSession {
    public let core: any EmulatorCore
    public let descriptor: CoreDescriptor
    public private(set) var pacer: FramePacer
    public let presenter: FramePresenter
    public let router: InputRouter

    /// Set by the frontend when it has a surface. A software core still needs one, because the
    /// presenter's output has to go somewhere.
    public private(set) var surface: RenderSurface?

    // Running totals, so a frontend can show real numbers rather than a guess.
    public private(set) var framesRun = 0
    public private(set) var framesPresented = 0
    public private(set) var framesDropped = 0

    private let audio: AudioSink
    /// Supplies the current frame for software cores. GPU-native cores leave this nil and present
    /// into the surface themselves — the two halves of the same contract.
    private let frameProvider: (() -> FrameBuffer?)?

    public init(core: any EmulatorCore,
                audio: AudioSink,
                inputMap: CoreInputMap,
                displayInterval: Double = 1.0 / 60.0,
                frameProvider: (() -> FrameBuffer?)? = nil) {
        self.core = core
        self.descriptor = type(of: core).descriptor
        self.audio = audio
        self.router = InputRouter(map: inputMap)
        self.presenter = FramePresenter()
        self.frameProvider = frameProvider
        self.pacer = FramePacer(guestFrameDuration: descriptor.frameDuration,
                                displayInterval: displayInterval)
    }

    // MARK: Lifecycle

    public func start(surface: RenderSurface) throws {
        self.surface = surface
        try core.start(surface: surface, audio: audio)
        pacer.resync()
    }

    public func pause() throws { try core.pause() }

    public func resume() throws {
        try core.resume()
        // Without this, the time spent paused is owed to the guest and it sprints to catch up.
        pacer.resync()
    }

    public func stop() {
        core.stop()
        surface = nil
        router.reset()
    }

    // MARK: Driving

    /// Advance by one display refresh.
    ///
    /// `elapsed` should be the measured time since the previous call; passing nil assumes the
    /// nominal display interval, which is wrong whenever a vsync was missed.
    @discardableResult
    public func advance(elapsed: Double? = nil) -> SessionTick {
        guard core.state == .running else {
            return SessionTick(decision: .repeatLastFrame, framesRun: 0, didPresent: false)
        }

        let decision = pacer.tick(elapsed: elapsed)
        var toRun = 0
        switch decision {
        case .run(let n): toRun = n
        case .repeatLastFrame: toRun = 0
        case .dropped(let n): framesDropped += n
        }

        guard toRun > 0 else {
            return SessionTick(decision: decision, framesRun: 0, didPresent: false)
        }

        // Only the last frame of a catch-up burst is worth presenting; the intermediate ones are
        // never seen. This is what `processVideo:` on the contract is for.
        for i in 0..<toRun {
            core.runFrame(processVideo: i == toRun - 1)
            framesRun += 1
        }

        var presented = false
        if let frameProvider, let frame = frameProvider() {
            if (try? presenter.present(frame)) != nil {
                framesPresented += 1
                presented = true
            }
        }
        return SessionTick(decision: decision, framesRun: toRun, didPresent: presented)
    }

    // MARK: Input

    /// Route a normalized event to the core. The only input entry point a frontend needs.
    public func send(_ event: InputEvent) {
        guard let routed = router.handle(event) else { return }
        core.activate(input: routed.raw, value: routed.value, playerIndex: routed.player)
    }

    public func releaseAllInputs() {
        router.reset()
        core.resetInputs()
    }

    // MARK: Surface

    public func surfaceDidResize(to size: PixelSize) {
        guard var s = surface else { return }
        s.resize(to: size)
        surface = s
        core.surfaceDidResize(s)
    }

    public func setResolutionScale(_ scale: Double) {
        guard var s = surface else { return }
        s.setResolutionScale(scale)
        surface = s
        core.surfaceDidResize(s)
    }

    public func displayRefreshDidChange(to interval: Double) {
        pacer.displayRefreshDidChange(to: interval)
    }

    public func setRate(_ rate: Double) {
        let clamped = min(max(rate, descriptor.supportedRates.lowerBound),
                          descriptor.supportedRates.upperBound)
        pacer.setRate(clamped)
    }
}
