/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonBsnesGlue.h"
#include <stddef.h>
#include <stdbool.h>

extern void bsnes_retro_init(void);
extern void bsnes_retro_deinit(void);
extern unsigned bsnes_retro_api_version(void);
extern void bsnes_retro_get_system_info(struct retro_system_info *info);
extern void bsnes_retro_get_system_av_info(struct retro_system_av_info *info);
extern void bsnes_retro_set_environment(retro_environment_t);
extern void bsnes_retro_set_video_refresh(retro_video_refresh_t);
extern void bsnes_retro_set_audio_sample(retro_audio_sample_t);
extern void bsnes_retro_set_audio_sample_batch(retro_audio_sample_batch_t);
extern void bsnes_retro_set_input_poll(retro_input_poll_t);
extern void bsnes_retro_set_input_state(retro_input_state_t);
extern void bsnes_retro_reset(void);
extern void bsnes_retro_run(void);
extern size_t bsnes_retro_serialize_size(void);
extern bool bsnes_retro_serialize(void *data, size_t size);
extern bool bsnes_retro_unserialize(const void *data, size_t size);
extern bool bsnes_retro_load_game(const struct retro_game_info *game);
extern void bsnes_retro_unload_game(void);
extern void *bsnes_retro_get_memory_data(unsigned id);
extern size_t bsnes_retro_get_memory_size(unsigned id);

static const avalon_libretro_vtable g_vtable = {
    .id = "libretro.bsnes",
    .set_environment = bsnes_retro_set_environment,
    .set_video_refresh = bsnes_retro_set_video_refresh,
    .set_audio_sample = bsnes_retro_set_audio_sample,
    .set_audio_sample_batch = bsnes_retro_set_audio_sample_batch,
    .set_input_poll = bsnes_retro_set_input_poll,
    .set_input_state = bsnes_retro_set_input_state,
    .init = bsnes_retro_init,
    .deinit = bsnes_retro_deinit,
    .api_version = bsnes_retro_api_version,
    .get_system_info = bsnes_retro_get_system_info,
    .get_system_av_info = bsnes_retro_get_system_av_info,
    .load_game = bsnes_retro_load_game,
    .unload_game = bsnes_retro_unload_game,
    .run = bsnes_retro_run,
    .reset = bsnes_retro_reset,
    .serialize_size = bsnes_retro_serialize_size,
    .serialize = bsnes_retro_serialize,
    .unserialize = bsnes_retro_unserialize,
    .get_memory_data = bsnes_retro_get_memory_data,
    .get_memory_size = bsnes_retro_get_memory_size,
};

const avalon_libretro_vtable *avalon_bsnes_vtable(void) { return &g_vtable; }
