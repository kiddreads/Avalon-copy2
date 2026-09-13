// Renames bsnes's libretro entry points so this core's symbols don't collide with the other
// libretro cores statically linked into the same AvalonCore binary. Unlike Genesis Plus GX,
// Nestopia and mGBA, bsnes's own target-libretro/libretro.cpp has no libretro-common dependency
// at all (it only includes <cassert> and "libretro.h") -- its own utility layer is nall, entirely
// namespaced already under C++ namespaces (SuperFamicom::, Emulator::, nall::), so the RETRO_API
// entry points below are the only symbols that need renaming.
#ifndef AVALON_BSNES_NAMESPACE_H
#define AVALON_BSNES_NAMESPACE_H

#define retro_init bsnes_retro_init
#define retro_deinit bsnes_retro_deinit
#define retro_api_version bsnes_retro_api_version
#define retro_get_system_info bsnes_retro_get_system_info
#define retro_get_system_av_info bsnes_retro_get_system_av_info
#define retro_set_environment bsnes_retro_set_environment
#define retro_set_video_refresh bsnes_retro_set_video_refresh
#define retro_set_audio_sample bsnes_retro_set_audio_sample
#define retro_set_audio_sample_batch bsnes_retro_set_audio_sample_batch
#define retro_set_input_poll bsnes_retro_set_input_poll
#define retro_set_input_state bsnes_retro_set_input_state
#define retro_set_controller_port_device bsnes_retro_set_controller_port_device
#define retro_reset bsnes_retro_reset
#define retro_run bsnes_retro_run
#define retro_serialize_size bsnes_retro_serialize_size
#define retro_serialize bsnes_retro_serialize
#define retro_unserialize bsnes_retro_unserialize
#define retro_cheat_reset bsnes_retro_cheat_reset
#define retro_cheat_set bsnes_retro_cheat_set
#define retro_load_game bsnes_retro_load_game
#define retro_load_game_special bsnes_retro_load_game_special
#define retro_unload_game bsnes_retro_unload_game
#define retro_get_region bsnes_retro_get_region
#define retro_get_memory_data bsnes_retro_get_memory_data
#define retro_get_memory_size bsnes_retro_get_memory_size

#endif
