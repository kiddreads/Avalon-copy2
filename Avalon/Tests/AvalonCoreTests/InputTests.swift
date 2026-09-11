import Testing
@testable import AvalonCore

// The per-core encodings below are the real ones read out of Folium's cores. The point of the
// abstraction is that they stay confined to a CoreInputMap instead of leaking into the UI layer.

/// NDS hardware KEYINPUT mask — Folium/Grape/Grape.swift:11-26
private let grapeMap = CoreInputMap(coreID: "grape", mapping: [
    .a: 1 << 0, .b: 1 << 1, .select: 1 << 2, .start: 1 << 3,
    .right: 1 << 4, .left: 1 << 5, .up: 1 << 6, .down: 1 << 7,
    .r1: 1 << 8, .l1: 1 << 9, .touchX: 1 << 16, .touchY: 1 << 17, .touch: 1 << 18,
])

/// 3DS core's arbitrary 700-range integers — Folium/Cytrus/Cytrus.swift:12-40
private let cytrusMap = CoreInputMap(coreID: "cytrus", mapping: [
    .a: 700, .b: 701, .x: 702, .y: 703,
    .up: 704, .down: 705, .left: 706, .right: 707,
    .l1: 708, .r1: 709, .start: 710, .select: 711,
    .leftStickX: 780, .leftStickY: 781, .touch: 782,
])

@Test("The same Avalon control reaches two cores in their own encodings")
func oneControlTwoEncodings() {
    let grape = InputRouter(map: grapeMap)
    let cytrus = InputRouter(map: cytrusMap)
    let press = InputEvent(control: .a, value: 1, device: .touchOverlay)

    #expect(grape.handle(press)?.raw == 1)      // NDS bit 0
    #expect(cytrus.handle(press)?.raw == 700)   // 3DS arbitrary id
    // Folium needs ten overloads of press(button:) to achieve this; here the UI sends one event.
}

@Test("A control the core cannot represent is recorded, not silently dropped")
func unmappedIsRecorded() {
    let grape = InputRouter(map: grapeMap)
    // The DS has no X/Y face buttons, so a shared overlay will send controls it cannot use.
    #expect(grape.handle(InputEvent(control: .x, value: 1, device: .touchOverlay)) == nil)
    #expect(grape.unmappedControls.contains(.x))
    // And a control it does have still works afterwards.
    #expect(grape.handle(InputEvent(control: .b, value: 1, device: .touchOverlay))?.raw == 2)
}

@Test("Analog deadzone is applied and the usable range is rescaled")
func deadzoneRescales() {
    let r = InputRouter(map: cytrusMap, deadzone: 0.2)
    // Inside the deadzone reads as zero.
    #expect(r.handle(InputEvent(control: .leftStickX, value: 0.1, device: .mfiController(id: "x")))?.value == 0)
    // At full deflection it is still full scale, not 0.8 — a naive subtraction loses the top.
    let full = r.handle(InputEvent(control: .leftStickX, value: 1.0, device: .mfiController(id: "x")))
    #expect(abs((full?.value ?? 0) - 1.0) < 1e-9)
    // Halfway past the deadzone maps proportionally.
    let mid = r.handle(InputEvent(control: .leftStickX, value: 0.6, device: .mfiController(id: "x")))
    #expect(abs((mid?.value ?? 0) - 0.5) < 1e-9)
}

@Test("Buttons clamp to 0...1 and axes to -1...1")
func valuesAreClamped() {
    let b = InputEvent(control: .a, value: 5, device: .keyboard)
    #expect(b.value == 1)
    let neg = InputEvent(control: .a, value: -3, device: .keyboard)
    #expect(neg.value == 0)
    let axis = InputEvent(control: .leftStickY, value: -9, device: .mfiController(id: "x"))
    #expect(axis.value == -1)
}

@Test("Repeated identical events do not re-issue to the core")
func redundantEventsSuppressed() {
    let r = InputRouter(map: cytrusMap)
    let press = InputEvent(control: .a, value: 1, device: .touchOverlay)
    #expect(r.handle(press) != nil)
    #expect(r.handle(press) == nil, "a held button should not spam the core every frame")
    #expect(r.handle(InputEvent(control: .a, value: 0, device: .touchOverlay)) != nil)
}

@Test("Two players are tracked independently")
func playersAreIndependent() {
    // Manic EMU keys mappings by (controllerName, gameType) with no player index
    // (ControllerMapping.swift:16-28), so it cannot do this at all.
    let r = InputRouter(map: cytrusMap)
    r.handle(InputEvent(control: .a, value: 1, playerIndex: 0, device: .mfiController(id: "p1")))
    r.handle(InputEvent(control: .b, value: 1, playerIndex: 1, device: .mfiController(id: "p2")))
    #expect(r.value(of: .a, player: 0) == 1)
    #expect(r.value(of: .a, player: 1) == 0)
    #expect(r.value(of: .b, player: 1) == 1)
    #expect(r.activeControls.count == 2)
    r.reset()
    #expect(r.activeControls.isEmpty)
}

@Test("Bindings are keyed per device and player")
func mappingKeying() {
    var m = InputMapping(system: .nintendoDS)
    m.bind(InputBinding(device: .keyboard, code: 40, control: .a, playerIndex: 0))
    m.bind(InputBinding(device: .keyboard, code: 40, control: .b, playerIndex: 1))
    m.bind(InputBinding(device: .mfiController(id: "pad"), code: 40, control: .start))

    #expect(m.control(for: .keyboard, code: 40, playerIndex: 0) == .a)
    #expect(m.control(for: .keyboard, code: 40, playerIndex: 1) == .b)
    #expect(m.control(for: .mfiController(id: "pad"), code: 40) == .start)
    #expect(m.control(for: .keyboard, code: 99) == nil)

    m.unbind(device: .keyboard, code: 40, playerIndex: 0)
    #expect(m.control(for: .keyboard, code: 40, playerIndex: 0) == nil)
    #expect(m.control(for: .keyboard, code: 40, playerIndex: 1) == .b)
}
