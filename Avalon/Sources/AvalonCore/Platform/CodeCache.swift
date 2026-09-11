// Avalon — the allocated side of the JIT service.
//
// JITArbiter decides *whether* and *how much*; this hands out the memory and enforces the write
// discipline. Keeping them apart is what lets the policy be tested without mapping anything, and
// the mapping be tested without pretending to be four cores.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import Foundation
import AvalonJIT

public extension JITMode {
    init(_ c: avalon_jit_mode) {
        switch c {
        case AVALON_JIT_SIMULATOR: self = .simulator
        case AVALON_JIT_MAPJIT: self = .mapJIT
        case AVALON_JIT_DUALMAP: self = .dualMapped
        case AVALON_JIT_PROTECT_TOGGLE: self = .protectToggle
        default: self = .unavailable
        }
    }

    var cValue: avalon_jit_mode {
        switch self {
        case .simulator: return AVALON_JIT_SIMULATOR
        case .mapJIT: return AVALON_JIT_MAPJIT
        case .dualMapped: return AVALON_JIT_DUALMAP
        case .protectToggle: return AVALON_JIT_PROTECT_TOGGLE
        case .unavailable: return AVALON_JIT_UNAVAILABLE
        }
    }

    /// What this process can actually do, probed rather than assumed.
    static func detect() -> JITMode { JITMode(avalon_jit_detect()) }
}

/// A block of executable memory lent to one core.
///
/// The type exists so that "write through here, execute through there" is not something every
/// emitter has to remember. `writeOffset` is iPSX2's `g_code_rw_offset` idea: an emitter that
/// works in execute-space addresses adds it once and is correct in every mode.
public final class CodeCache {
    public let reservation: CodeCacheReservation
    public let mode: JITMode
    public var executableBase: UnsafeMutableRawPointer { region.rx }
    public var writableBase: UnsafeMutableRawPointer { region.rw }
    public var byteCount: Int { region.size }
    /// Add to an execute-space address to get its writable alias. Zero except in dual-mapped mode.
    public var writeOffset: Int { avalon_jit_rw_offset(&region) }
    /// Whether another thread may execute from this cache while it is being written.
    public var allowsConcurrentCodegen: Bool {
        avalon_jit_mode_allows_concurrent_codegen(mode.cValue) != 0
    }

    private var region: avalon_jit_region
    private let arbiter: JITArbiter
    private var released = false

    /// Ask the arbiter for a budget slice and map it.
    public init(owner: String, byteCount: Int, arbiter: JITArbiter) throws {
        self.arbiter = arbiter
        self.reservation = try arbiter.reserve(owner: owner, byteCount: byteCount)
        self.mode = arbiter.mode
        var r = avalon_jit_region()
        guard avalon_jit_alloc(&r, byteCount, arbiter.mode.cValue) == 0 else {
            try? arbiter.release(reservation)
            throw JITError.unavailable(reason: "could not map \(byteCount) bytes as \(arbiter.mode)")
        }
        self.region = r
    }

    deinit { release() }

    public func release() {
        guard !released else { return }
        released = true
        avalon_jit_free(&region)
        try? arbiter.release(reservation)
    }

    /// Emit code into the cache.
    ///
    /// The closure receives the writable alias. Protection is opened before and closed after, and
    /// the instruction cache is invalidated on the way out — forgetting that last step produces the
    /// kind of bug that only appears on some devices, under some timing.
    ///
    /// Not re-entrant, matching the underlying primitive.
    public func write<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) throws -> R {
        guard !released else { throw JITError.notReserved(owner: reservation.owner) }
        guard avalon_jit_begin_write(&region) == 0 else {
            throw JITError.unavailable(reason: "could not make code memory writable")
        }
        defer { _ = avalon_jit_end_write(&region) }
        return try body(UnsafeMutableRawBufferPointer(start: region.rw, count: region.size))
    }

    /// Reinterpret an offset in the cache as a callable function.
    ///
    /// Unsafe by nature: nothing verifies that the bytes there are valid code.
    public func function<F>(at offset: Int = 0, as type: F.Type) -> F {
        precondition(offset >= 0 && offset < byteCount, "offset outside code cache")
        return unsafeBitCast(executableBase.advanced(by: offset), to: type)
    }
}
