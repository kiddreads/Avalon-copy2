/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonChip8.h"
#include <string.h>

/* Standard CHIP-8 hex font, 5 bytes per glyph, loaded at 0x000. */
static const uint8_t FONT[80] = {
    0xF0,0x90,0x90,0x90,0xF0, 0x20,0x60,0x20,0x20,0x70,
    0xF0,0x10,0xF0,0x80,0xF0, 0xF0,0x10,0xF0,0x10,0xF0,
    0x90,0x90,0xF0,0x10,0x10, 0xF0,0x80,0xF0,0x10,0xF0,
    0xF0,0x80,0xF0,0x90,0xF0, 0xF0,0x10,0x20,0x40,0x40,
    0xF0,0x90,0xF0,0x90,0xF0, 0xF0,0x90,0xF0,0x10,0xF0,
    0xF0,0x90,0xF0,0x90,0x90, 0xE0,0x90,0xE0,0x90,0xE0,
    0xF0,0x80,0x80,0x80,0xF0, 0xE0,0x90,0x90,0x90,0xE0,
    0xF0,0x80,0xF0,0x80,0xF0, 0xF0,0x80,0xF0,0x80,0x80,
};

void chip8_reset(chip8_state *s, uint32_t seed) {
    memset(s, 0, sizeof *s);
    memcpy(s->memory, FONT, sizeof FONT);
    s->pc = CHIP8_PROGRAM_START;
    s->rng = seed ? seed : 0x13579BDFu;
}

int chip8_load(chip8_state *s, const uint8_t *rom, size_t size) {
    if (!rom || size == 0) return -1;
    if (size > (size_t)(CHIP8_MEMORY_SIZE - CHIP8_PROGRAM_START)) return -1;
    memcpy(s->memory + CHIP8_PROGRAM_START, rom, size);
    return 0;
}

/* xorshift32: deterministic across runs and platforms, which a save state requires. */
static uint8_t next_random(chip8_state *s) {
    uint32_t x = s->rng;
    x ^= x << 13; x ^= x >> 17; x ^= x << 5;
    s->rng = x;
    return (uint8_t)(x & 0xFF);
}

int chip8_step(chip8_state *s) {
    if (s->halted) return -1;

    /* FX0A blocks the whole machine until a key goes down. */
    if (s->waiting_for_key) {
        for (uint8_t k = 0; k < CHIP8_KEY_COUNT; ++k) {
            if (s->keys[k]) {
                s->v[s->wait_register] = k;
                s->waiting_for_key = 0;
                break;
            }
        }
        if (s->waiting_for_key) return 0;
    }

    if (s->pc + 1 >= CHIP8_MEMORY_SIZE) { s->halted = 1; return -1; }
    const uint16_t op = (uint16_t)(s->memory[s->pc] << 8 | s->memory[s->pc + 1]);
    s->pc += 2;

    const uint8_t  x   = (op >> 8) & 0x0F;
    const uint8_t  y   = (op >> 4) & 0x0F;
    const uint8_t  n   =  op       & 0x0F;
    const uint8_t  kk  =  op       & 0xFF;
    const uint16_t nnn =  op       & 0x0FFF;

    switch (op & 0xF000) {
    case 0x0000:
        if (op == 0x00E0) {                      /* CLS */
            memset(s->screen, 0, sizeof s->screen);
        } else if (op == 0x00EE) {               /* RET */
            if (s->sp == 0) { s->halted = 1; return -1; }
            s->pc = s->stack[--s->sp];
        } else { s->halted = 1; return -1; }
        break;
    case 0x1000: s->pc = nnn; break;             /* JP nnn */
    case 0x2000:                                  /* CALL nnn */
        if (s->sp >= CHIP8_STACK_DEPTH) { s->halted = 1; return -1; }
        s->stack[s->sp++] = s->pc;
        s->pc = nnn;
        break;
    case 0x3000: if (s->v[x] == kk)      s->pc += 2; break;
    case 0x4000: if (s->v[x] != kk)      s->pc += 2; break;
    case 0x5000: if (n == 0 && s->v[x] == s->v[y]) s->pc += 2; break;
    case 0x6000: s->v[x]  = kk; break;
    case 0x7000: s->v[x] = (uint8_t)(s->v[x] + kk); break;
    case 0x8000:
        switch (n) {
        case 0x0: s->v[x]  = s->v[y]; break;
        case 0x1: s->v[x] |= s->v[y]; break;
        case 0x2: s->v[x] &= s->v[y]; break;
        case 0x3: s->v[x] ^= s->v[y]; break;
        case 0x4: { uint16_t r = (uint16_t)s->v[x] + s->v[y];
                    s->v[0xF] = r > 0xFF; s->v[x] = (uint8_t)r; } break;
        case 0x5: { uint8_t f = s->v[x] >= s->v[y];
                    s->v[x] = (uint8_t)(s->v[x] - s->v[y]); s->v[0xF] = f; } break;
        case 0x6: { uint8_t f = s->v[x] & 1; s->v[x] >>= 1; s->v[0xF] = f; } break;
        case 0x7: { uint8_t f = s->v[y] >= s->v[x];
                    s->v[x] = (uint8_t)(s->v[y] - s->v[x]); s->v[0xF] = f; } break;
        case 0xE: { uint8_t f = (s->v[x] >> 7) & 1; s->v[x] = (uint8_t)(s->v[x] << 1);
                    s->v[0xF] = f; } break;
        default: s->halted = 1; return -1;
        }
        break;
    case 0x9000: if (n == 0 && s->v[x] != s->v[y]) s->pc += 2; break;
    case 0xA000: s->i = nnn; break;
    case 0xB000: s->pc = (uint16_t)(nnn + s->v[0]); break;
    case 0xC000: s->v[x] = next_random(s) & kk; break;
    case 0xD000: {                                /* DRW: XOR sprite, VF = collision */
        s->v[0xF] = 0;
        for (uint8_t row = 0; row < n; ++row) {
            const uint16_t addr = (uint16_t)(s->i + row);
            if (addr >= CHIP8_MEMORY_SIZE) break;
            const uint8_t bits = s->memory[addr];
            const int py = (s->v[y] + row) % CHIP8_SCREEN_H;
            for (uint8_t col = 0; col < 8; ++col) {
                if (!((bits >> (7 - col)) & 1)) continue;
                const int px = (s->v[x] + col) % CHIP8_SCREEN_W;
                uint8_t *p = &s->screen[py * CHIP8_SCREEN_W + px];
                if (*p) s->v[0xF] = 1;
                *p ^= 1;
            }
        }
        break;
    }
    case 0xE000:
        if (kk == 0x9E) { if (s->v[x] < CHIP8_KEY_COUNT && s->keys[s->v[x]]) s->pc += 2; }
        else if (kk == 0xA1) { if (!(s->v[x] < CHIP8_KEY_COUNT && s->keys[s->v[x]])) s->pc += 2; }
        else { s->halted = 1; return -1; }
        break;
    case 0xF000:
        switch (kk) {
        case 0x07: s->v[x] = s->delay_timer; break;
        case 0x0A: s->waiting_for_key = 1; s->wait_register = x; break;
        case 0x15: s->delay_timer = s->v[x]; break;
        case 0x18: s->sound_timer = s->v[x]; break;
        case 0x1E: s->i = (uint16_t)(s->i + s->v[x]); break;
        case 0x29: s->i = (uint16_t)((s->v[x] & 0x0F) * 5); break;
        case 0x33:
            if (s->i + 2 < CHIP8_MEMORY_SIZE) {
                s->memory[s->i]     = (uint8_t)(s->v[x] / 100);
                s->memory[s->i + 1] = (uint8_t)((s->v[x] / 10) % 10);
                s->memory[s->i + 2] = (uint8_t)(s->v[x] % 10);
            }
            break;
        case 0x55:
            for (uint8_t r = 0; r <= x; ++r)
                if (s->i + r < CHIP8_MEMORY_SIZE) s->memory[s->i + r] = s->v[r];
            break;
        case 0x65:
            for (uint8_t r = 0; r <= x; ++r)
                if (s->i + r < CHIP8_MEMORY_SIZE) s->v[r] = s->memory[s->i + r];
            break;
        default: s->halted = 1; return -1;
        }
        break;
    default: s->halted = 1; return -1;
    }
    return 0;
}

void chip8_run_frame(chip8_state *s, int ipf) {
    for (int k = 0; k < ipf && !s->halted; ++k) chip8_step(s);
    if (s->delay_timer) s->delay_timer--;
    if (s->sound_timer) s->sound_timer--;
}

void chip8_render_rgba(const chip8_state *s, uint32_t *dst,
                       uint32_t on_color, uint32_t off_color) {
    for (size_t p = 0; p < CHIP8_SCREEN_W * CHIP8_SCREEN_H; ++p)
        dst[p] = s->screen[p] ? on_color : off_color;
}

int chip8_is_beeping(const chip8_state *s) { return s->sound_timer > 0; }
