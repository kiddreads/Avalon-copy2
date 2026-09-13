/* Avalon — namespacing Genesis Plus GX's libretro port for static linking.
 *
 * Same technique and same reason as mgba_namespace.h: RETRO_API symbols are renamed at the
 * preprocessor level, ahead of the vendored, unmodified `Libretro/genesis-plus-gx/libretro/libretro.c`,
 * so two statically-linked cores never collide on a bare `retro_run`.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later (Avalon's own text, this file)
 * Genesis Plus GX itself is LGPL-2.1-or-later; see NOTICE.md.
 */

#ifndef AVALON_GENESISPLUSGX_NAMESPACE_H
#define AVALON_GENESISPLUSGX_NAMESPACE_H

#define retro_init                       gpgx_retro_init
#define retro_deinit                     gpgx_retro_deinit
#define retro_api_version                gpgx_retro_api_version
#define retro_get_system_info             gpgx_retro_get_system_info
#define retro_get_system_av_info          gpgx_retro_get_system_av_info
#define retro_set_environment            gpgx_retro_set_environment
#define retro_set_video_refresh           gpgx_retro_set_video_refresh
#define retro_set_audio_sample            gpgx_retro_set_audio_sample
#define retro_set_audio_sample_batch      gpgx_retro_set_audio_sample_batch
#define retro_set_input_poll              gpgx_retro_set_input_poll
#define retro_set_input_state             gpgx_retro_set_input_state
#define retro_set_controller_port_device  gpgx_retro_set_controller_port_device
#define retro_reset                      gpgx_retro_reset
#define retro_run                        gpgx_retro_run
#define retro_serialize_size              gpgx_retro_serialize_size
#define retro_serialize                  gpgx_retro_serialize
#define retro_unserialize                gpgx_retro_unserialize
#define retro_cheat_reset                gpgx_retro_cheat_reset
#define retro_cheat_set                  gpgx_retro_cheat_set
#define retro_load_game                  gpgx_retro_load_game
#define retro_load_game_special           gpgx_retro_load_game_special
#define retro_unload_game                gpgx_retro_unload_game
#define retro_get_region                 gpgx_retro_get_region
#define retro_get_memory_data             gpgx_retro_get_memory_data
#define retro_get_memory_size             gpgx_retro_get_memory_size

#include "libretro.h"

#endif
