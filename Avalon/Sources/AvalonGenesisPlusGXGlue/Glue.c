/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonGenesisPlusGXGlue.h"
#include <stddef.h>
#include <stdbool.h>

/* The real, already-renamed link-time symbols genesisplusgx_namespace.h produced in
   AvalonLibretroGenesisPlusGX -- the object file contains these names, not the bare `retro_*`
   ones, so that's what has to be declared and referenced here. */
extern void gpgx_retro_init(void);
extern void gpgx_retro_deinit(void);
extern unsigned gpgx_retro_api_version(void);
extern void gpgx_retro_get_system_info(struct retro_system_info *info);
extern void gpgx_retro_get_system_av_info(struct retro_system_av_info *info);
extern void gpgx_retro_set_environment(retro_environment_t);
extern void gpgx_retro_set_video_refresh(retro_video_refresh_t);
extern void gpgx_retro_set_audio_sample(retro_audio_sample_t);
extern void gpgx_retro_set_audio_sample_batch(retro_audio_sample_batch_t);
extern void gpgx_retro_set_input_poll(retro_input_poll_t);
extern void gpgx_retro_set_input_state(retro_input_state_t);
extern void gpgx_retro_reset(void);
extern void gpgx_retro_run(void);
extern size_t gpgx_retro_serialize_size(void);
extern bool gpgx_retro_serialize(void *data, size_t size);
extern bool gpgx_retro_unserialize(const void *data, size_t size);
extern bool gpgx_retro_load_game(const struct retro_game_info *game);
extern void gpgx_retro_unload_game(void);
extern void *gpgx_retro_get_memory_data(unsigned id);
extern size_t gpgx_retro_get_memory_size(unsigned id);

static const avalon_libretro_vtable g_vtable = {
    .id = "libretro.genesis-plus-gx",
    .set_environment = gpgx_retro_set_environment,
    .set_video_refresh = gpgx_retro_set_video_refresh,
    .set_audio_sample = gpgx_retro_set_audio_sample,
    .set_audio_sample_batch = gpgx_retro_set_audio_sample_batch,
    .set_input_poll = gpgx_retro_set_input_poll,
    .set_input_state = gpgx_retro_set_input_state,
    .init = gpgx_retro_init,
    .deinit = gpgx_retro_deinit,
    .api_version = gpgx_retro_api_version,
    .get_system_info = gpgx_retro_get_system_info,
    .get_system_av_info = gpgx_retro_get_system_av_info,
    .load_game = gpgx_retro_load_game,
    .unload_game = gpgx_retro_unload_game,
    .run = gpgx_retro_run,
    .reset = gpgx_retro_reset,
    .serialize_size = gpgx_retro_serialize_size,
    .serialize = gpgx_retro_serialize,
    .unserialize = gpgx_retro_unserialize,
    .get_memory_data = gpgx_retro_get_memory_data,
    .get_memory_size = gpgx_retro_get_memory_size,
};

const avalon_libretro_vtable *avalon_genesisplusgx_vtable(void) { return &g_vtable; }
