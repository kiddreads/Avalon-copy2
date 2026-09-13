/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonPCSXGlue.h"
#include <stddef.h>
#include <stdbool.h>

extern void pcsx_retro_init(void);
extern void pcsx_retro_deinit(void);
extern unsigned pcsx_retro_api_version(void);
extern void pcsx_retro_get_system_info(struct retro_system_info *info);
extern void pcsx_retro_get_system_av_info(struct retro_system_av_info *info);
extern void pcsx_retro_set_environment(retro_environment_t);
extern void pcsx_retro_set_video_refresh(retro_video_refresh_t);
extern void pcsx_retro_set_audio_sample(retro_audio_sample_t);
extern void pcsx_retro_set_audio_sample_batch(retro_audio_sample_batch_t);
extern void pcsx_retro_set_input_poll(retro_input_poll_t);
extern void pcsx_retro_set_input_state(retro_input_state_t);
extern void pcsx_retro_reset(void);
extern void pcsx_retro_run(void);
extern size_t pcsx_retro_serialize_size(void);
extern bool pcsx_retro_serialize(void *data, size_t size);
extern bool pcsx_retro_unserialize(const void *data, size_t size);
extern bool pcsx_retro_load_game(const struct retro_game_info *game);
extern void pcsx_retro_unload_game(void);
extern void *pcsx_retro_get_memory_data(unsigned id);
extern size_t pcsx_retro_get_memory_size(unsigned id);

static const avalon_libretro_vtable g_vtable = {
    .id = "libretro.pcsx_rearmed",
    .set_environment = pcsx_retro_set_environment,
    .set_video_refresh = pcsx_retro_set_video_refresh,
    .set_audio_sample = pcsx_retro_set_audio_sample,
    .set_audio_sample_batch = pcsx_retro_set_audio_sample_batch,
    .set_input_poll = pcsx_retro_set_input_poll,
    .set_input_state = pcsx_retro_set_input_state,
    .init = pcsx_retro_init,
    .deinit = pcsx_retro_deinit,
    .api_version = pcsx_retro_api_version,
    .get_system_info = pcsx_retro_get_system_info,
    .get_system_av_info = pcsx_retro_get_system_av_info,
    .load_game = pcsx_retro_load_game,
    .unload_game = pcsx_retro_unload_game,
    .run = pcsx_retro_run,
    .reset = pcsx_retro_reset,
    .serialize_size = pcsx_retro_serialize_size,
    .serialize = pcsx_retro_serialize,
    .unserialize = pcsx_retro_unserialize,
    .get_memory_data = pcsx_retro_get_memory_data,
    .get_memory_size = pcsx_retro_get_memory_size,
};

const avalon_libretro_vtable *avalon_pcsx_vtable(void) { return &g_vtable; }
