// Avalon — Nestopia's controller mapping.
//
// Read from libretro.cpp's own `bindmap_default` (the table `bindmap` is initialised to,
// before any core-option toggle to `bindmap_shifted`), not assumed: unlike Genesis Plus GX,
// this one is a plain 1:1 -- RETRO_DEVICE_ID_JOYPAD_A is NES A, RETRO_DEVICE_ID_JOYPAD_B is NES
// B. The NES touch layout's own bindings ("A" -> Avalon `.a`, "B" -> Avalon `.b`) already assume
// exactly this, so this table exists to make that assumption checkable against the real source
// rather than silently relying on it being obviously true.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

public extension NestopiaSpec {
    static var inputMap: CoreInputMap {
        CoreInputMap(coreID: coreID, mapping: [
            .up: 4, .down: 5, .left: 6, .right: 7,   // RETRO_DEVICE_ID_JOYPAD_{UP,DOWN,LEFT,RIGHT}
            .a: 8,       // RETRO_DEVICE_ID_JOYPAD_A -> NES A
            .b: 0,       // RETRO_DEVICE_ID_JOYPAD_B -> NES B
            .start: 3,   // RETRO_DEVICE_ID_JOYPAD_START
            .select: 2,  // RETRO_DEVICE_ID_JOYPAD_SELECT
        ])
    }
}
