// Avalon — Genesis Plus GX's controller mapping.
//
// libretro's RETRO_DEVICE_ID_JOYPAD_* ids are NOT Genesis button names — the core translates them
// internally (`libretro/libretro.c`'s `osd_input_update_internal`, `DEVICE_PAD6B`/`PAD3B`/`PAD2B`
// cases), and the translation is not the naive one: RETRO_DEVICE_ID_JOYPAD_Y maps to the
// Genesis's own "A" button, RETRO_DEVICE_ID_JOYPAD_A maps to Genesis "C", and so on. Guessing
// "RETRO A means Genesis A" would silently cross every face button. This table is read directly
// from that switch, not assumed:
//
//   RETRO B -> Genesis B     RETRO A -> Genesis C     RETRO Y -> Genesis A
//   RETRO X -> Genesis Y     RETRO L -> Genesis X     RETRO R -> Genesis Z
//   RETRO SELECT -> Genesis MODE     RETRO START -> Genesis START
//
// DEVICE_PAD6B is the core's own default pad type (`config.input[i].padtype = DEVICE_PAD6B` at
// startup), so no `retro_set_controller_port_device` call is required for the 6-button mapping
// to be live.
//
// The Genesis touch layout (`Resources/controls.json`, platform "genesis") binds its on-screen
// buttons by their real Genesis label -- "A" to Avalon's `.a`, "C" to `.r1`, etc. -- so this map
// exists to translate FROM that Avalon `Control` TO the RETRO id the core expects, keeping the
// crossed-mapping risk in exactly one place.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

public extension GenesisPlusGXSpec {
    static var inputMap: CoreInputMap {
        CoreInputMap(coreID: coreID, mapping: [
            .up: 4, .down: 5, .left: 6, .right: 7,          // RETRO_DEVICE_ID_JOYPAD_{UP,DOWN,LEFT,RIGHT}
            .a: 1,     // Genesis A  -> RETRO Y
            .b: 0,     // Genesis B  -> RETRO B
            .r1: 8,    // Genesis C  -> RETRO A
            .y: 9,     // Genesis Y  -> RETRO X
            .x: 10,    // Genesis X  -> RETRO L
            .r2: 11,   // Genesis Z  -> RETRO R
            .start: 3,     // RETRO_DEVICE_ID_JOYPAD_START
            .select: 2,    // RETRO_DEVICE_ID_JOYPAD_SELECT -> Genesis MODE
        ])
    }
}
