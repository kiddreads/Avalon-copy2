// Avalon — JIT as a platform service.
//
// This file exists because of a conflict that only shows up when you put these projects in one
// process. Four cores, four incompatible strategies, one process-global resource:
//
//   • MeloNX reserves 512 MB–1 GB of JIT cache at startup and then calls `BreakJITDetach()`, after
//     which *no further JIT memory can be mapped in the process*
//     (`MeloNX/src/Ryujinx.Cpu/LightningJit/Cache/DualMappedNoWxCache.cs:15`,
//      `MeloNX/src/Ryujinx.Memory/MemoryBlock.cs:118-126`).
//   • iPSX2 has the most complete strategy — four modes, TXM detection, MAP_JIT with an mprotect
//     fallback, dual RX/RW `vm_remap`, and a `brk` debugger handshake under a sigsetjmp net
//     (`iPSX2/iPSX2/cpp/common/Darwin/DarwinMisc.cpp:645-860`).
//   • PPSSPP flips RW↔RX with plain `mprotect` and no MAP_JIT at all; its code buffers are
//     explicitly non-nestable, i.e. single-threaded codegen only
//     (`PPSSPP/Common/CodeBlock.h:96-148`).
//   • Fin removed JIT entirely and runs Dolphin interpreted (`Fin/Readme.md`).
//
// Left alone, whichever core starts second silently loses its JIT. So Avalon owns acquisition, the
// W^X regime and cache reservation; cores request code memory and never probe or detach.
//
// This file is the contract and the arbitration policy — both testable off-device. The Darwin
// implementation that actually calls mmap/vm_remap belongs in AvalonPlatform and is not here.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation

/// How executable memory can be obtained on the current device.
///
/// Mirrors the four-mode scheme iPSX2 arrived at, which is the most complete treatment in the
/// repository.
public enum JITMode: String, Sendable, Equatable, CaseIterable {
    /// Simulator: ordinary RWX works.
    case simulator
    /// `MAP_JIT` + `pthread_jit_write_protect_np`. Fast, concurrency-safe, the modern Apple path.
    case mapJIT
    /// Dual RX/RW mapping of the same physical pages via `vm_remap`. Write through one address,
    /// execute through the other, never reprotect
    /// (`MeloNX/src/Ryujinx.Memory/DualMappedJitAllocator.cs:85-105`).
    case dualMapped
    /// Toggle page protection around every write. Works, but forbids concurrent
    /// compile-while-executing — PPSSPP's scheme, and the reason its codegen is single-threaded.
    case protectToggle
    /// No executable memory. Cores must fall back to an interpreter or refuse to start.
    case unavailable

    /// Whether one thread may compile while another executes previously generated code.
    public var supportsConcurrentCodegen: Bool {
        switch self {
        case .simulator, .mapJIT, .dualMapped: return true
        case .protectToggle, .unavailable: return false
        }
    }
}

/// A reservation of executable memory, owned by Avalon and lent to one core.
public struct CodeCacheReservation: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let owner: String
    public let byteCount: Int
    public let mode: JITMode
    public init(id: UUID = UUID(), owner: String, byteCount: Int, mode: JITMode) {
        self.id = id; self.owner = owner; self.byteCount = byteCount; self.mode = mode
    }
}

public enum JITError: Error, Equatable {
    case unavailable(reason: String)
    /// The request would exceed the process-wide budget. Carries what was left.
    case budgetExhausted(requested: Int, available: Int)
    case notReserved(owner: String)
    /// A core tried to acquire JIT after the process-wide capability was finalized.
    case alreadyFinalized
}

/// Arbitrates executable memory across every core in the process.
///
/// The budget is fixed at construction because that is the real constraint: on iOS the whole
/// reservation must be taken before the process loses the ability to map more.
public final class JITArbiter: @unchecked Sendable {
    public let mode: JITMode
    public let totalBudget: Int

    private let lock = NSLock()
    private var reservations: [UUID: CodeCacheReservation] = [:]
    private var finalized = false

    public init(mode: JITMode, totalBudget: Int) {
        self.mode = mode
        self.totalBudget = max(0, totalBudget)
    }

    public var reservedBytes: Int {
        lock.lock(); defer { lock.unlock() }
        return reservations.values.reduce(0) { $0 + $1.byteCount }
    }

    public var availableBytes: Int {
        lock.lock(); defer { lock.unlock() }
        return totalBudget - reservations.values.reduce(0) { $0 + $1.byteCount }
    }

    public var isFinalized: Bool {
        lock.lock(); defer { lock.unlock() }
        return finalized
    }

    /// Reserve code memory for a core.
    ///
    /// Refusing rather than over-committing is the whole point: an over-commit on device does not
    /// fail here, it fails inside whichever core maps last, as a crash or a silent interpreter
    /// fallback nobody notices until a game runs at a tenth speed.
    public func reserve(owner: String, byteCount: Int) throws -> CodeCacheReservation {
        lock.lock(); defer { lock.unlock() }
        guard mode != .unavailable else {
            throw JITError.unavailable(reason: "No executable memory is available on this device")
        }
        guard !finalized else { throw JITError.alreadyFinalized }
        let used = reservations.values.reduce(0) { $0 + $1.byteCount }
        let free = totalBudget - used
        guard byteCount <= free else {
            throw JITError.budgetExhausted(requested: byteCount, available: free)
        }
        let r = CodeCacheReservation(owner: owner, byteCount: byteCount, mode: mode)
        reservations[r.id] = r
        return r
    }

    public func release(_ reservation: CodeCacheReservation) throws {
        lock.lock(); defer { lock.unlock() }
        guard reservations.removeValue(forKey: reservation.id) != nil else {
            throw JITError.notReserved(owner: reservation.owner)
        }
    }

    /// Close the process-wide JIT capability.
    ///
    /// Models MeloNX's one-shot `BreakJITDetach()`. Avalon calls this — a core never does — and only
    /// once every core that needs code memory has it.
    public func finalizeCapability() {
        lock.lock(); defer { lock.unlock() }
        finalized = true
    }

    /// Whether a core can run at all, given what it needs and what the device allows.
    public func admissibility(of descriptor: CoreDescriptor) -> Admissibility {
        if descriptor.capabilities.contains(.requiresJIT) {
            guard mode != .unavailable else { return .refused(reason: "core requires JIT; none available") }
            return .admitted
        }
        if descriptor.capabilities.contains(.jitOptional), mode == .unavailable {
            return .degraded(reason: "running interpreted; expect substantially reduced performance")
        }
        return .admitted
    }

    public enum Admissibility: Equatable {
        case admitted
        case degraded(reason: String)
        case refused(reason: String)

        public var canRun: Bool { if case .refused = self { return false }; return true }
    }
}
