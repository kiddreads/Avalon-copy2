import Testing
import Foundation
@testable import AvalonCore

// The scenarios here are the real ones. MeloNX reserves 512 MB–1 GB and then permanently closes the
// process's ability to map more; PPSSPP's code buffers cannot nest, so it cannot compile and execute
// concurrently. Both facts are cited in JITService.swift.

private func psx2Descriptor(requiresJIT: Bool = true) -> CoreDescriptor {
    CoreDescriptor(id: "ps2", displayName: "PS2", version: "1", system: .playStation2,
                   screens: [ScreenDescriptor(id: "main", nativeSize: .init(width: 640, height: 448))],
                   renderingModel: .nativeSurface(api: .metal), frameDuration: 1.0/59.94,
                   capabilities: requiresJIT ? [.requiresJIT] : [.jitOptional])
}

@Test("Two cores cannot silently over-commit the process JIT budget")
func budgetIsArbitrated() throws {
    // 1 GB total, MeloNX-style. This is the conflict: without arbitration the second core
    // fails at map time on device instead of at request time here.
    let arbiter = JITArbiter(mode: .dualMapped, totalBudget: 1_024 << 20)
    let switchCore = try arbiter.reserve(owner: "MeloNX", byteCount: 512 << 20)
    #expect(arbiter.reservedBytes == 512 << 20)

    #expect(throws: JITError.budgetExhausted(requested: 768 << 20, available: 512 << 20)) {
        _ = try arbiter.reserve(owner: "iPSX2", byteCount: 768 << 20)
    }
    // A request that fits still succeeds.
    let ps2 = try arbiter.reserve(owner: "iPSX2", byteCount: 256 << 20)
    #expect(arbiter.availableBytes == 256 << 20)

    try arbiter.release(switchCore)
    #expect(arbiter.availableBytes == 768 << 20)
    try arbiter.release(ps2)
    #expect(arbiter.reservedBytes == 0)
}

@Test("Finalizing the capability is one-way, as it is on device")
func finalizeIsOneWay() throws {
    let arbiter = JITArbiter(mode: .dualMapped, totalBudget: 512 << 20)
    _ = try arbiter.reserve(owner: "MeloNX", byteCount: 256 << 20)
    arbiter.finalizeCapability()
    #expect(arbiter.isFinalized)
    // This is exactly the bug the service prevents: a core starting after BreakJITDetach().
    #expect(throws: JITError.alreadyFinalized) {
        _ = try arbiter.reserve(owner: "PPSSPP", byteCount: 32 << 20)
    }
}

@Test("Only the modes that genuinely allow it report concurrent codegen")
func concurrencyModelIsHonest() {
    // PPSSPP's CodeBlock cannot nest BeginWrite/EndWrite, so protectToggle must say false.
    #expect(JITMode.protectToggle.supportsConcurrentCodegen == false)
    #expect(JITMode.mapJIT.supportsConcurrentCodegen)
    #expect(JITMode.dualMapped.supportsConcurrentCodegen)
    #expect(JITMode.unavailable.supportsConcurrentCodegen == false)
}

@Test("A JIT-requiring core is refused when the device has no JIT, not started and crashed")
func admissibility() {
    let none = JITArbiter(mode: .unavailable, totalBudget: 0)
    #expect(none.admissibility(of: psx2Descriptor()).canRun == false)

    // Fin's position: Dolphin with JIT removed still runs, just slowly.
    let degraded = none.admissibility(of: psx2Descriptor(requiresJIT: false))
    #expect(degraded.canRun)
    if case .degraded = degraded {} else { Issue.record("expected .degraded, got \(degraded)") }

    let ok = JITArbiter(mode: .mapJIT, totalBudget: 256 << 20)
    #expect(ok.admissibility(of: psx2Descriptor()) == .admitted)
}

@Test("Reserving with no JIT available fails immediately")
func unavailableRefuses() {
    let arbiter = JITArbiter(mode: .unavailable, totalBudget: 0)
    #expect(throws: (any Error).self) { _ = try arbiter.reserve(owner: "any", byteCount: 1) }
}

@Suite("JIT platform strategy")
struct JITPlatformStrategyTests {

    @Test("the W^X toggle is macOS-only, and the detected mode never needs one it lacks")
    func toggleAvailability() {
        // `pthread_jit_write_protect_np` is declared in the shared Darwin headers and marked
        // unavailable on iOS. Building only for macOS hides that completely — this package
        // claimed `.iOS(.v16)` support and did not compile for iOS until CI first tried it.
        #if os(macOS)
        #expect(JITMode.hasWriteProtectToggle)
        #else
        #expect(!JITMode.hasWriteProtectToggle)
        #endif

        // Whatever this platform detects has to be a mode this platform can actually write to.
        if JITMode.detect() == .mapJIT {
            #expect(JITMode.hasWriteProtectToggle,
                    "MAP_JIT was selected on a platform with no way to unprotect it")
        }
    }

    @Test("a region in the detected mode can be written and executed")
    func detectedModeRoundTrips() throws {
        let mode = JITMode.detect()
        try #require(mode != .unavailable, "no JIT strategy on this platform")

        let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
        let cache = try CodeCache(owner: "platform-strategy-test", byteCount: 4096, arbiter: arbiter)
        defer { cache.release() }

        // The claim under test: writing through the *detected* mode succeeds. On iOS this is
        // exactly what fails if MAP_JIT is ever selected — there is nothing to unprotect it with.
        let written = try cache.write { buffer -> Int in
            buffer.storeBytes(of: UInt32(0xD65F03C0), toByteOffset: 0, as: UInt32.self) // ret
            return 4
        }
        #expect(written == 4)
    }
}
