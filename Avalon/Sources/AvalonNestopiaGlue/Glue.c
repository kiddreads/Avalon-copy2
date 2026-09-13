/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonNestopiaGlue.h"
#include <stddef.h>
#include <stdbool.h>

extern void nestopia_retro_init(void);
extern void nestopia_retro_deinit(void);
extern unsigned nestopia_retro_api_version(void);
extern void nestopia_retro_get_system_info(struct retro_system_info *info);
extern void nestopia_retro_get_system_av_info(struct retro_system_av_info *info);
extern void nestopia_retro_set_environment(retro_environment_t);
extern void nestopia_retro_set_video_refresh(retro_video_refresh_t);
extern void nestopia_retro_set_audio_sample(retro_audio_sample_t);
extern void nestopia_retro_set_audio_sample_batch(retro_audio_sample_batch_t);
extern void nestopia_retro_set_input_poll(retro_input_poll_t);
extern void nestopia_retro_set_input_state(retro_input_state_t);
extern void nestopia_retro_reset(void);
extern void nestopia_retro_run(void);
extern size_t nestopia_retro_serialize_size(void);
extern bool nestopia_retro_serialize(void *data, size_t size);
extern bool nestopia_retro_unserialize(const void *data, size_t size);
extern bool nestopia_retro_load_game(const struct retro_game_info *game);
extern void nestopia_retro_unload_game(void);
extern void *nestopia_retro_get_memory_data(unsigned id);
extern size_t nestopia_retro_get_memory_size(unsigned id);

static const avalon_libretro_vtable g_vtable = {
    .id = "libretro.nestopia",
    .set_environment = nestopia_retro_set_environment,
    .set_video_refresh = nestopia_retro_set_video_refresh,
    .set_audio_sample = nestopia_retro_set_audio_sample,
    .set_audio_sample_batch = nestopia_retro_set_audio_sample_batch,
    .set_input_poll = nestopia_retro_set_input_poll,
    .set_input_state = nestopia_retro_set_input_state,
    .init = nestopia_retro_init,
    .deinit = nestopia_retro_deinit,
    .api_version = nestopia_retro_api_version,
    .get_system_info = nestopia_retro_get_system_info,
    .get_system_av_info = nestopia_retro_get_system_av_info,
    .load_game = nestopia_retro_load_game,
    .unload_game = nestopia_retro_unload_game,
    .run = nestopia_retro_run,
    .reset = nestopia_retro_reset,
    .serialize_size = nestopia_retro_serialize_size,
    .serialize = nestopia_retro_serialize,
    .unserialize = nestopia_retro_unserialize,
    .get_memory_data = nestopia_retro_get_memory_data,
    .get_memory_size = nestopia_retro_get_memory_size,
};

const avalon_libretro_vtable *avalon_nestopia_vtable(void) { return &g_vtable; }
