/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonLibretroTestCore.h"
#include <string.h>
#include <stdlib.h>

#define TC_W 64
#define TC_H 32

static retro_environment_t        env_cb;
static retro_video_refresh_t      video_cb;
static retro_audio_sample_batch_t audio_cb;
static retro_input_poll_t         poll_cb;
static retro_input_state_t        input_cb;

static uint32_t framebuffer[TC_W * TC_H];
static uint8_t  sram[64];
static unsigned tick;
static unsigned cursor;
static int      loaded;

static void tc_set_environment(retro_environment_t cb) { env_cb = cb; }
static void tc_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
static void tc_set_audio_sample(retro_audio_sample_t cb) { (void)cb; }
static void tc_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_cb = cb; }
static void tc_set_input_poll(retro_input_poll_t cb) { poll_cb = cb; }
static void tc_set_input_state(retro_input_state_t cb) { input_cb = cb; }

static void tc_init(void) {
    tick = 0; cursor = 0; loaded = 0;
    memset(framebuffer, 0, sizeof framebuffer);
    memset(sram, 0, sizeof sram);
    /* A real core negotiates its pixel format here, and refuses to run if the frontend says no. */
    enum retro_pixel_format fmt = RETRO_PIXEL_FORMAT_XRGB8888;
    if (env_cb) env_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt);
}

static void tc_deinit(void) { loaded = 0; }
static unsigned tc_api_version(void) { return RETRO_API_VERSION; }

static void tc_get_system_info(struct retro_system_info *info) {
    memset(info, 0, sizeof *info);
    info->library_name = "Avalon Test Core";
    info->library_version = "1.0";
    info->valid_extensions = "test|bin";
    info->need_fullpath = false;
    info->block_extract = true;
}

static void tc_get_system_av_info(struct retro_system_av_info *info) {
    memset(info, 0, sizeof *info);
    info->geometry.base_width = TC_W;
    info->geometry.base_height = TC_H;
    info->geometry.max_width = TC_W;
    info->geometry.max_height = TC_H;
    info->geometry.aspect_ratio = (float)TC_W / (float)TC_H;
    info->timing.fps = 60.0;
    info->timing.sample_rate = 44100.0;
}

static bool tc_load_game(const struct retro_game_info *game) {
    if (!game || !game->data || game->size == 0) return false;
    /* Seed the cursor from the ROM so a different ROM produces a different picture. */
    cursor = ((const uint8_t *)game->data)[0] % TC_W;
    loaded = 1;
    return true;
}

static void tc_unload_game(void) { loaded = 0; }

static void tc_run(void) {
    if (poll_cb) poll_cb();

    /* Input actually moves something, so a frontend that mis-maps buttons produces a wrong frame
       rather than passing silently. */
    if (input_cb) {
        if (input_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT)) cursor = (cursor + 1) % TC_W;
        if (input_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT))  cursor = (cursor + TC_W - 1) % TC_W;
        if (input_cb(0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A))     sram[0] = 0xA5;
    }

    memset(framebuffer, 0, sizeof framebuffer);
    for (unsigned y = 0; y < TC_H; y++) framebuffer[y * TC_W + cursor] = 0x00FFFFFFu;
    tick++;

    if (video_cb) video_cb(framebuffer, TC_W, TC_H, TC_W * sizeof(uint32_t));

    if (audio_cb) {
        int16_t frames[735 * 2];
        for (unsigned i = 0; i < 735; i++) {
            int16_t v = (int16_t)(((i + tick) % 64) * 400 - 12800);
            frames[i * 2] = v;
            frames[i * 2 + 1] = v;
        }
        audio_cb(frames, 735);
    }
}

static void tc_reset(void) { tick = 0; cursor = 0; }

struct tc_state { unsigned tick; unsigned cursor; uint8_t sram[64]; };

static size_t tc_serialize_size(void) { return sizeof(struct tc_state); }

static bool tc_serialize(void *data, size_t size) {
    if (size < sizeof(struct tc_state)) return false;
    struct tc_state s = { tick, cursor, { 0 } };
    memcpy(s.sram, sram, sizeof sram);
    memcpy(data, &s, sizeof s);
    return true;
}

static bool tc_unserialize(const void *data, size_t size) {
    if (size < sizeof(struct tc_state)) return false;
    struct tc_state s;
    memcpy(&s, data, sizeof s);
    tick = s.tick; cursor = s.cursor;
    memcpy(sram, s.sram, sizeof sram);
    return true;
}

static void *tc_get_memory_data(unsigned id) {
    return id == RETRO_MEMORY_SAVE_RAM ? sram : NULL;
}
static size_t tc_get_memory_size(unsigned id) {
    return id == RETRO_MEMORY_SAVE_RAM ? sizeof sram : 0;
}

static const avalon_libretro_vtable tc_vtable = {
    .id = "avalon.test",
    .set_environment = tc_set_environment,
    .set_video_refresh = tc_set_video_refresh,
    .set_audio_sample = tc_set_audio_sample,
    .set_audio_sample_batch = tc_set_audio_sample_batch,
    .set_input_poll = tc_set_input_poll,
    .set_input_state = tc_set_input_state,
    .init = tc_init,
    .deinit = tc_deinit,
    .api_version = tc_api_version,
    .get_system_info = tc_get_system_info,
    .get_system_av_info = tc_get_system_av_info,
    .load_game = tc_load_game,
    .unload_game = tc_unload_game,
    .run = tc_run,
    .reset = tc_reset,
    .serialize_size = tc_serialize_size,
    .serialize = tc_serialize,
    .unserialize = tc_unserialize,
    .get_memory_data = tc_get_memory_data,
    .get_memory_size = tc_get_memory_size,
};

const avalon_libretro_vtable *avalon_test_core_vtable(void) { return &tc_vtable; }
