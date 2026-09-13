/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonMGBAGlue.h"
#include <stddef.h>
#include <stdbool.h>

extern void mgba_retro_init(void);
extern void mgba_retro_deinit(void);
extern unsigned mgba_retro_api_version(void);
extern void mgba_retro_get_system_info(struct retro_system_info *info);
extern void mgba_retro_get_system_av_info(struct retro_system_av_info *info);
extern void mgba_retro_set_environment(retro_environment_t);
extern void mgba_retro_set_video_refresh(retro_video_refresh_t);
extern void mgba_retro_set_audio_sample(retro_audio_sample_t);
extern void mgba_retro_set_audio_sample_batch(retro_audio_sample_batch_t);
extern void mgba_retro_set_input_poll(retro_input_poll_t);
extern void mgba_retro_set_input_state(retro_input_state_t);
extern void mgba_retro_reset(void);
extern void mgba_retro_run(void);
extern size_t mgba_retro_serialize_size(void);
extern bool mgba_retro_serialize(void *data, size_t size);
extern bool mgba_retro_unserialize(const void *data, size_t size);
extern bool mgba_retro_load_game(const struct retro_game_info *game);
extern void mgba_retro_unload_game(void);
extern void *mgba_retro_get_memory_data(unsigned id);
extern size_t mgba_retro_get_memory_size(unsigned id);

static const avalon_libretro_vtable g_vtable = {
    .id = "libretro.mgba",
    .set_environment = mgba_retro_set_environment,
    .set_video_refresh = mgba_retro_set_video_refresh,
    .set_audio_sample = mgba_retro_set_audio_sample,
    .set_audio_sample_batch = mgba_retro_set_audio_sample_batch,
    .set_input_poll = mgba_retro_set_input_poll,
    .set_input_state = mgba_retro_set_input_state,
    .init = mgba_retro_init,
    .deinit = mgba_retro_deinit,
    .api_version = mgba_retro_api_version,
    .get_system_info = mgba_retro_get_system_info,
    .get_system_av_info = mgba_retro_get_system_av_info,
    .load_game = mgba_retro_load_game,
    .unload_game = mgba_retro_unload_game,
    .run = mgba_retro_run,
    .reset = mgba_retro_reset,
    .serialize_size = mgba_retro_serialize_size,
    .serialize = mgba_retro_serialize,
    .unserialize = mgba_retro_unserialize,
    .get_memory_data = mgba_retro_get_memory_data,
    .get_memory_size = mgba_retro_get_memory_size,
};

const avalon_libretro_vtable *avalon_mgba_vtable(void) { return &g_vtable; }
