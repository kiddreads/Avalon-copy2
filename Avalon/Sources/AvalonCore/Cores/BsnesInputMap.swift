// Avalon — bsnes's controller mapping.
//
// Read from target-libretro/program.cpp's own polling order (a literal array of
// RETRO_DEVICE_ID_JOYPAD_UP/_DOWN/_LEFT/_RIGHT/_B/_A/_Y/_X/_L/_R/_SELECT/_START, in that order,
// feeding SNES::Controller::Gamepad's button indices in the same sequence) -- a plain 1:1, like
// Nestopia and mGBA and unlike Genesis Plus GX: RETRO A is SNES A, RETRO B is SNES B.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

public extension BsnesSpec {
    static var inputMap: CoreInputMap {
        CoreInputMap(coreID: coreID, mapping: [
            .up: 4, .down: 5, .left: 6, .right: 7,   // RETRO_DEVICE_ID_JOYPAD_{UP,DOWN,LEFT,RIGHT}
            .a: 8,       // RETRO_DEVICE_ID_JOYPAD_A
            .b: 0,       // RETRO_DEVICE_ID_JOYPAD_B
            .x: 9,       // RETRO_DEVICE_ID_JOYPAD_X
            .y: 1,       // RETRO_DEVICE_ID_JOYPAD_Y
            .l1: 10,     // RETRO_DEVICE_ID_JOYPAD_L
            .r1: 11,     // RETRO_DEVICE_ID_JOYPAD_R
            .start: 3,   // RETRO_DEVICE_ID_JOYPAD_START
            .select: 2,  // RETRO_DEVICE_ID_JOYPAD_SELECT
        ])
    }
}
