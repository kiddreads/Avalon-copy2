// Avalon — mGBA's controller mapping.
//
// Read from libretro.c's own polling order (a comment block listing RETRO_DEVICE_ID_JOYPAD_A,
// _B, _SELECT, _START, _RIGHT, _LEFT, _UP, _DOWN, _R, _L in that order, matching GBA's real
// button order) and its descriptor table -- a plain 1:1, like Nestopia and unlike Genesis Plus
// GX: RETRO A is GBA A, RETRO B is GBA B. RETRO_DEVICE_ID_JOYPAD_X/_Y map to mGBA's "Turbo A"/
// "Turbo B" (rapid-fire variants), which are not real Game Boy hardware buttons and are not
// wired here.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

public extension MGBASpec {
    static var inputMap: CoreInputMap {
        CoreInputMap(coreID: coreID, mapping: [
            .up: 4, .down: 5, .left: 6, .right: 7,   // RETRO_DEVICE_ID_JOYPAD_{UP,DOWN,LEFT,RIGHT}
            .a: 8,       // RETRO_DEVICE_ID_JOYPAD_A
            .b: 0,       // RETRO_DEVICE_ID_JOYPAD_B
            .start: 3,   // RETRO_DEVICE_ID_JOYPAD_START
            .select: 2,  // RETRO_DEVICE_ID_JOYPAD_SELECT
            .l1: 10,     // RETRO_DEVICE_ID_JOYPAD_L -- Game Boy Advance only; unused on GB/GBC
            .r1: 11,     // RETRO_DEVICE_ID_JOYPAD_R -- Game Boy Advance only; unused on GB/GBC
        ])
    }
}
