/*
 * Avalon — CHIP-8 reference core.
 *
 * This exists to answer a question the rest of the package cannot: does Avalon's core contract
 * actually host an emulator, end to end, or does it merely compile?
 *
 * CHIP-8 was chosen because it is a real emulated system — CPU, addressable memory, framebuffer,
 * hex keypad, 60 Hz delay and sound timers — while being small enough to implement correctly and
 * verify exhaustively. It needs no BIOS and no copyrighted ROM, so the tests assemble their own.
 *
 * It is not a toy stand-in for the contract: it loads a ROM, executes instructions, renders frames
 * through Avalon's presenter, takes input through Avalon's router, produces audio through Avalon's
 * mixer, and serialises save states. If the contract is wrong, this is where it shows.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef AVALON_CHIP8_H
#define AVALON_CHIP8_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CHIP8_MEMORY_SIZE   4096
#define CHIP8_PROGRAM_START 0x200
#define CHIP8_SCREEN_W      64
#define CHIP8_SCREEN_H      32
#define CHIP8_STACK_DEPTH   16
#define CHIP8_KEY_COUNT     16

typedef struct {
    uint8_t  memory[CHIP8_MEMORY_SIZE];
    uint8_t  v[16];                 /* V0..VF; VF is the flag register */
    uint16_t i;                     /* address register */
    uint16_t pc;
    uint16_t stack[CHIP8_STACK_DEPTH];
    uint8_t  sp;
    uint8_t  delay_timer;
    uint8_t  sound_timer;
    uint8_t  keys[CHIP8_KEY_COUNT]; /* 1 = held */
    uint8_t  screen[CHIP8_SCREEN_W * CHIP8_SCREEN_H]; /* 0 or 1 per pixel */
    uint32_t rng;                   /* deterministic, so tests and save states are reproducible */
    uint8_t  waiting_for_key;       /* FX0A state */
    uint8_t  wait_register;
    uint8_t  halted;                /* set on an illegal instruction rather than faulting */
} chip8_state;

/* Reset and load the built-in hex font. */
void chip8_reset(chip8_state *s, uint32_t seed);

/* Load a ROM at 0x200. Returns 0 on success, -1 if it does not fit. */
int chip8_load(chip8_state *s, const uint8_t *rom, size_t size);

/* Execute one instruction. Returns 0 normally, -1 if halted. */
int chip8_step(chip8_state *s);

/* Run one 60 Hz frame: `ipf` instructions then one timer tick. */
void chip8_run_frame(chip8_state *s, int ipf);

/* Expand the 1-bit screen into RGBA8888 for Avalon's presenter. */
void chip8_render_rgba(const chip8_state *s, uint32_t *dst,
                       uint32_t on_color, uint32_t off_color);

/* Non-zero while the sound timer is running — CHIP-8's only audio. */
int chip8_is_beeping(const chip8_state *s);

#ifdef __cplusplus
}
#endif
#endif
