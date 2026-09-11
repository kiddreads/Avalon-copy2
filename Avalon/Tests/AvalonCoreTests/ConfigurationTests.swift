import Testing
import Foundation
@testable import AvalonCore

private func store() -> ConfigurationStore {
    ConfigurationStore(declaring: [
        SettingKey("upscale", default: .int(1)),
        SettingKey("vsync", default: .bool(true)),
        SettingKey("volume", default: .double(1.0)),
        SettingKey("cytrusTextureFilter", default: .string("none"), appliesTo: ["cytrus"]),
    ])
}

@Test("Narrower scopes win: game beats system beats global")
func scopePrecedence() {
    let s = store()
    #expect(s.set("upscale", .int(2), scope: .global))
    #expect(s.set("upscale", .int(3), scope: .system, system: .nintendo3DS))
    #expect(s.set("upscale", .int(4), scope: .game, gameID: "game-a"))

    #expect(s.resolve().int("upscale") == 2)
    #expect(s.resolve(system: .nintendo3DS).int("upscale") == 3)
    #expect(s.resolve(system: .nintendo3DS, gameID: "game-a").int("upscale") == 4)
    // A different game falls back to the system value, not the other game's.
    #expect(s.resolve(system: .nintendo3DS, gameID: "game-b").int("upscale") == 3)
}

@Test("Resolution reports which scope a value came from")
func originIsReported() {
    let s = store()
    s.set("vsync", .bool(false), scope: .game, gameID: "g")
    let r = s.resolve(gameID: "g")
    #expect(r.bool("vsync") == false)
    #expect(r.origin(of: "vsync") == .game)
    // An untouched setting has its default and no origin — so a UI can show "not overridden".
    #expect(r.double("volume") == 1.0)
    #expect(r.origin(of: "volume") == nil)
}

@Test("A type mismatch is rejected rather than silently stored")
func typeMismatchRejected() {
    // Folium stores ~40 settings and silently discards every non-Bool when handing them to the
    // core (Cytrus.swift:145-152), so several are displayed and never applied. Refusing the write
    // is how that stops being possible.
    let s = store()
    #expect(s.set("upscale", .string("high"), scope: .global) == false)
    #expect(s.set("vsync", .int(1), scope: .global) == false)
    #expect(s.resolve().int("upscale") == 1)   // untouched default
}

@Test("An undeclared key is rejected")
func undeclaredRejected() {
    let s = store()
    #expect(s.set("neverDeclared", .bool(true), scope: .global) == false)
    #expect(s.resolve()["neverDeclared"] == nil)
}

@Test("Settings scoped to another core are not offered to this one")
func coreScopedSettings() {
    let s = store()
    #expect(s.resolve(coreID: "cytrus")["cytrusTextureFilter"] != nil)
    #expect(s.resolve(coreID: "dolphin")["cytrusTextureFilter"] == nil)
}

@Test("Clearing an override falls back to the next scope")
func clearingFallsBack() {
    let s = store()
    s.set("upscale", .int(2), scope: .global)
    s.set("upscale", .int(5), scope: .game, gameID: "g")
    #expect(s.resolve(gameID: "g").int("upscale") == 5)
    s.clear("upscale", scope: .game, gameID: "g")
    #expect(s.resolve(gameID: "g").int("upscale") == 2)
}
