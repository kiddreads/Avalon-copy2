import Testing
import Foundation
@testable import AvalonCore

// These tests generate real ARM64 and execute it. That is the point: the brief is explicit that an
// integration is not complete because a stub compiles. If the JIT service is wrong, these fault.

private typealias AddFn = @convention(c) (Int32) -> Int32
private typealias MulFn = @convention(c) (Int32, Int32) -> Int32

/// add w0, w0, #imm ; ret
private func emitAddImm(_ imm: UInt32) -> [UInt32] {
    precondition(imm < 4096)
    return [0x1100_0000 | (imm << 10), 0xD65F_03C0]
}
/// mul w0, w0, w1 ; ret
private let emitMul: [UInt32] = [0x1B01_7C00, 0xD65F_03C0]

@Test("This process can actually obtain executable memory")
func modeIsDetected() {
    let mode = JITMode.detect()
    #expect(mode != .unavailable, "no JIT mode available; the remaining tests cannot be meaningful")
    #expect(mode.supportsConcurrentCodegen)
}

@Test("Generated ARM64 runs through the code cache")
func generatedCodeExecutes() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
    let cache = try CodeCache(owner: "test", byteCount: 4096, arbiter: arbiter)

    try cache.write { buf in
        emitAddImm(7).withUnsafeBytes { src in
            buf.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
    }
    let f = cache.function(as: AddFn.self)
    #expect(f(35) == 42)
}

@Test("Two functions at different offsets both execute")
func multipleBlocks() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
    let cache = try CodeCache(owner: "test", byteCount: 4096, arbiter: arbiter)

    let secondOffset = 64
    try cache.write { buf in
        emitAddImm(100).withUnsafeBytes { src in
            buf.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
        emitMul.withUnsafeBytes { src in
            buf.baseAddress!.advanced(by: secondOffset)
                .copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
    }
    #expect(cache.function(as: AddFn.self)(1) == 101)
    #expect(cache.function(at: secondOffset, as: MulFn.self)(6, 7) == 42)
}

@Test("Code can be rewritten in place and the icache is invalidated")
func rewriteIsVisible() throws {
    // Skipping the icache flush is the classic bug here: the old code keeps running, but only on
    // some devices and only sometimes. If end_write did not invalidate, this would flake.
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
    let cache = try CodeCache(owner: "test", byteCount: 4096, arbiter: arbiter)

    for imm in [UInt32(1), 7, 100, 4095] {
        try cache.write { buf in
            emitAddImm(imm).withUnsafeBytes { src in
                buf.baseAddress!.copyMemory(from: src.baseAddress!, byteCount: src.count)
            }
        }
        #expect(cache.function(as: AddFn.self)(0) == Int32(imm), "imm \(imm)")
    }
}

@Test("The write offset is what an emitter needs, and is mode-appropriate")
func writeOffsetMatchesMode() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
    let cache = try CodeCache(owner: "test", byteCount: 4096, arbiter: arbiter)

    switch cache.mode {
    case .dualMapped:
        // Distinct addresses aliasing the same physical pages.
        #expect(cache.writeOffset != 0)
        #expect(cache.writableBase != cache.executableBase)
    default:
        #expect(cache.writeOffset == 0)
        #expect(cache.writableBase == cache.executableBase)
    }
    // Either way, writing at executableBase + writeOffset must be correct.
    try cache.write { _ in
        let target = cache.executableBase.advanced(by: cache.writeOffset)
        emitAddImm(11).withUnsafeBytes { src in
            target.copyMemory(from: src.baseAddress!, byteCount: src.count)
        }
    }
    #expect(cache.function(as: AddFn.self)(31) == 42)
}

@Test("Releasing a cache returns its budget to the arbiter")
func releaseReturnsBudget() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 256 << 10)
    do {
        let cache = try CodeCache(owner: "core-a", byteCount: 128 << 10, arbiter: arbiter)
        #expect(arbiter.reservedBytes == 128 << 10)
        cache.release()
    }
    #expect(arbiter.reservedBytes == 0)
    // And the freed budget is usable by the next core.
    let second = try CodeCache(owner: "core-b", byteCount: 256 << 10, arbiter: arbiter)
    #expect(second.byteCount >= 256 << 10)
}

@Test("A core that exceeds the arbitrated budget never gets memory mapped")
func overBudgetIsRefusedBeforeMapping() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 64 << 10)
    #expect(throws: (any Error).self) {
        _ = try CodeCache(owner: "greedy", byteCount: 1 << 20, arbiter: arbiter)
    }
    #expect(arbiter.reservedBytes == 0, "a failed reservation must not leak budget")
}

@Test("Concurrent codegen is reported honestly for the active mode")
func concurrencyReporting() throws {
    let mode = JITMode.detect()
    try #require(mode != .unavailable)
    let arbiter = JITArbiter(mode: mode, totalBudget: 1 << 20)
    let cache = try CodeCache(owner: "test", byteCount: 4096, arbiter: arbiter)
    #expect(cache.allowsConcurrentCodegen == mode.supportsConcurrentCodegen)
}
