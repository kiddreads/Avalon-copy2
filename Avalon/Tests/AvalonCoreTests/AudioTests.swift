import Testing
import Foundation
import AvalonAudio

// The claim being tested is a quality claim, so it is measured rather than asserted.
// Reference: Olli Niemitalo, "Polynomial Interpolators for High-Quality Resampling of
// Oversampled Audio" (2001), p.43 — the kernel Dolphin uses and Avalon adapts.

private func hermite(_ s: [Float], _ t: Float) -> Float {
    var a = s
    return a.withUnsafeMutableBufferPointer { avalon_hermite6($0.baseAddress!, t) }
}

@Test("The kernel interpolates: at t=0 it returns the sample itself")
func kernelIsInterpolating() {
    // A true interpolator passes through its knots. A merely-approximating kernel does not,
    // and would soften every waveform slightly even at unity ratio.
    for probe in [[0,0,1,0,0,0], [0,0,0,1,0,0], [1,2,3,4,5,6]] as [[Float]] {
        #expect(abs(hermite(probe, 0) - probe[2]) < 1e-5, "t=0 should yield s2 for \(probe)")
    }
}

@Test("The kernel preserves a constant (partition of unity)")
func kernelPreservesDC() {
    // If the coefficients did not sum to 1 at every t, DC would wander and the output would
    // breathe in level as the phase walks.
    let flat = [Float](repeating: 0.75, count: 6)
    for i in 0...20 {
        let t = Float(i) / 20
        #expect(abs(hermite(flat, t) - 0.75) < 1e-5, "DC drift at t=\(t)")
    }
}

@Test("6-point Hermite beats linear interpolation on a real signal")
func hermiteBeatsLinear() {
    // Resample a 1 kHz sine at a non-integer ratio and compare against the analytic value.
    // This is the quality difference between this mixer and PPSSPP's shipping StereoResampler,
    // which is two-tap linear.
    let f = 1000.0, sr = 44100.0, ratio = 48000.0 / 44100.0
    var hermiteErr = 0.0, linearErr = 0.0
    var n = 0

    for k in stride(from: 10.0, to: 4000.0, by: 1.0) {
        let pos = k * (1.0 / ratio)
        let i = Int(pos.rounded(.down))
        let t = Float(pos - Double(i))
        let s: [Float] = (-2...3).map { Float(sin(2 * Double.pi * f * Double(i + $0) / sr)) }
        let ideal = sin(2 * Double.pi * f * pos / sr)

        hermiteErr += pow(Double(hermite(s, t)) - ideal, 2)
        let lin = Double(s[2]) * (1 - Double(t)) + Double(s[3]) * Double(t)
        linearErr += pow(lin - ideal, 2)
        n += 1
    }
    let hRMS = sqrt(hermiteErr / Double(n)), lRMS = sqrt(linearErr / Double(n))
    // Expect at least an order of magnitude; on this signal it is far more.
    #expect(hRMS < lRMS / 10, "hermite RMS \(hRMS) vs linear \(lRMS)")
    print("  resampling RMS error — hermite \(hRMS), linear \(lRMS), ratio \(lRMS/hRMS)x better")
}

@Test("Rate control adjusts latency, never pitch, and stays inside its band")
func rateControlIsBounded() {
    let nominal = 44100.0 / 48000.0
    let target = 1024
    // Queue too full -> walk faster; too empty -> walk slower. Never beyond ±1%.
    let full = avalon_mixer_rate_control(nominal, 4096, target, 0.01)
    let empty = avalon_mixer_rate_control(nominal, 0, target, 0.01)
    let onTarget = avalon_mixer_rate_control(nominal, target, target, 0.01)

    #expect(full > nominal && empty < nominal)
    #expect(abs(onTarget - nominal) < 1e-12)
    #expect(full <= nominal * 1.01 + 1e-12)
    #expect(empty >= nominal * 0.99 - 1e-12)
    // PPSSPP's StereoResampler corrects the same drift by pitch-bending ±1.36%, which is audible
    // on sustained tones. Here the correction cannot touch pitch at all.
}

@Test("Audio survives a round trip through the mixer at unity rate")
func roundTrip() {
    let m = avalon_mixer_create(48000, 48000, 8)!
    defer { avalon_mixer_destroy(m) }

    // Push several granules of a steady tone.
    var input = [Int16]()
    for i in 0..<4096 {
        let v = Int16(16000 * sin(2 * Double.pi * 440 * Double(i) / 48000))
        input.append(v); input.append(v)
    }
    _ = input.withUnsafeBufferPointer { avalon_mixer_push_s16(m, $0.baseAddress!, 4096) }
    #expect(avalon_mixer_queued_frames(m) > 0)

    var out = [Float](repeating: 0, count: 2048 * 2)
    _ = out.withUnsafeMutableBufferPointer { avalon_mixer_pull_f32(m, $0.baseAddress!, 2048) }

    // Output must be finite, bounded, and carry real signal once the fade-in completes.
    #expect(out.allSatisfy { $0.isFinite && abs($0) <= 1.5 })
    let tail = out.suffix(2048)
    let energy = tail.reduce(0) { $0 + Double($1 * $1) } / Double(tail.count)
    #expect(energy > 1e-4, "expected audible signal, got energy \(energy)")
}

@Test("An underrun fades out instead of clicking")
func underrunFades() {
    let m = avalon_mixer_create(48000, 48000, 8)!
    defer { avalon_mixer_destroy(m) }
    // Pull with nothing queued at all.
    var out = [Float](repeating: 99, count: 512 * 2)
    _ = out.withUnsafeMutableBufferPointer { avalon_mixer_pull_f32(m, $0.baseAddress!, 512) }
    #expect(out.allSatisfy { $0.isFinite })
    // Silence, not garbage, and certainly not the 99 sentinel.
    #expect(out.allSatisfy { abs($0) < 1e-3 })
}
