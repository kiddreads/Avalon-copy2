// Avalon — pcsx_rearmed's controller mapping.
//
// Read from frontend/libretro.c's own retro_input_descriptors table and its
// button_masks_from_id array -- a plain 1:1 against the standard libretro joypad IDs, like SNES,
// Nestopia and mGBA: RETRO A is PS1 Circle, RETRO B is PS1 Cross, RETRO X is Triangle, RETRO Y is
// Square (Sony's own face-button layout rotated relative to Nintendo's, but the RETRO_DEVICE_ID_*
// constant each one arrives on is unchanged). L2/R2 are real PS1 shoulder buttons, unlike the
// SNES/GBA cores before this one.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

public extension PCSXSpec {
    static var inputMap: CoreInputMap {
        CoreInputMap(coreID: coreID, mapping: [
            .up: 4, .down: 5, .left: 6, .right: 7,   // RETRO_DEVICE_ID_JOYPAD_{UP,DOWN,LEFT,RIGHT}
            .a: 8,       // RETRO_DEVICE_ID_JOYPAD_A  -- Circle
            .b: 0,       // RETRO_DEVICE_ID_JOYPAD_B  -- Cross
            .x: 9,       // RETRO_DEVICE_ID_JOYPAD_X  -- Triangle
            .y: 1,       // RETRO_DEVICE_ID_JOYPAD_Y  -- Square
            .l1: 10,     // RETRO_DEVICE_ID_JOYPAD_L
            .r1: 11,     // RETRO_DEVICE_ID_JOYPAD_R
            .l2: 12,     // RETRO_DEVICE_ID_JOYPAD_L2
            .r2: 13,     // RETRO_DEVICE_ID_JOYPAD_R2
            .start: 3,   // RETRO_DEVICE_ID_JOYPAD_START
            .select: 2,  // RETRO_DEVICE_ID_JOYPAD_SELECT
        ])
    }
}
