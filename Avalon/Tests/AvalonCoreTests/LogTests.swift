import Testing
import Foundation
@testable import AvalonCore

@Test("A disabled category never evaluates its message")
func disabledCostsNothing() {
    // This is the property that lets a core log per frame. If the autoclosure were evaluated
    // eagerly, every disabled trace would still format a string on the hot path.
    let log = Logger()
    log.setLevel(.error)
    var evaluated = false
    log.debug(.cpu, { evaluated = true; return "expensive" }())
    #expect(evaluated == false)

    log.setLevel(.debug)
    log.debug(.cpu, { evaluated = true; return "expensive" }())
    #expect(evaluated)
}

@Test("Per-category levels override the global level")
func perCategoryLevels() {
    let log = Logger()
    let sink = MemoryLogSink()
    log.add(sink: sink)
    log.setLevel(.error)                 // quiet everywhere
    log.setLevel(.trace, for: .jit)      // except the JIT, which is being debugged

    log.debug(.graphics, "should not appear")
    log.trace(.jit, "should appear")
    log.error(.graphics, "should appear")

    let messages = sink.all.map(\.message)
    #expect(messages.contains("should appear"))
    #expect(!messages.contains("should not appear"))
    #expect(sink.records(in: .jit).count == 1)
}

@Test("Categories are subsystem-shaped and extensible")
func categoriesAreNotConsoleSpecific() {
    // PPSSPP's categories are sceAudio/sceCtrl/sceDisplay/Atrac — unusable for a Dolphin core.
    #expect(LogCategory.graphics.rawValue == "graphics")
    let custom: LogCategory = "dolphin.dsp"
    #expect(custom.rawValue == "dolphin.dsp")
    let log = Logger(); let sink = MemoryLogSink()
    log.add(sink: sink); log.setLevel(.trace)
    log.info(custom, "core-specific category works")
    #expect(sink.records(in: custom).count == 1)
}

@Test("The memory sink bounds its own growth")
func memorySinkIsBounded() {
    let log = Logger(); let sink = MemoryLogSink(limit: 10)
    log.add(sink: sink); log.setLevel(.trace)
    for i in 0..<100 { log.info(.core, "msg \(i)") }
    #expect(sink.all.count == 10)
    #expect(sink.all.last?.message == "msg 99")   // newest kept, oldest dropped
}

@Test("Records carry their source location")
func recordsCarryLocation() {
    let log = Logger(); let sink = MemoryLogSink()
    log.add(sink: sink); log.setLevel(.trace)
    log.warning(.audio, "underrun")
    let r = try! #require(sink.all.first)
    #expect(r.file.contains("LogTests"))
    #expect(r.line > 0)
    #expect(r.level == .warning)
}
