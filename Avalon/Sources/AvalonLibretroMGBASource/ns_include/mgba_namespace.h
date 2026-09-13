/* Avalon — namespacing mGBA's libretro port for static linking.
 *
 * Same technique as genesisplusgx_namespace.h and nestopia_namespace.h: every RETRO_API entry
 * point mGBA's port defines is renamed at the preprocessor level, ahead of the vendored,
 * unmodified `Libretro/mgba` source, so no two statically-linked cores collide on a bare
 * `retro_run`. Unlike Nestopia, mGBA does not vendor its own copy of libretro-common (its
 * platform layer is self-contained, `src/util` instead), so there is no second, internal
 * namespace list needed here the way there was for Nestopia.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later (Avalon's own text, this file)
 * mGBA itself is MPL-2.0; see NOTICE.md.
 */

#ifndef AVALON_MGBA_NAMESPACE_H
#define AVALON_MGBA_NAMESPACE_H

/* Force flags.h first, ahead of anything else this translation unit includes. Darwin's own
   <string.h> declares strlcpy/strlcpy via a __builtin___strlcpy_chk-backed macro; mgba-util's
   own string.h ALSO declares plain `strlcpy` whenever it thinks the platform lacks one
   (`#ifndef HAVE_STRLCPY`). If flags.h's `#define HAVE_STRLCPY` has not been seen yet by the
   time that guard runs, the two declarations collide. Nothing in mGBA's own include chain reaches
   flags.h early enough on its own -- this guarantees it does. */
#include "mgba/flags.h"

#define retro_init                       mgba_retro_init
#define retro_deinit                     mgba_retro_deinit
#define retro_api_version                mgba_retro_api_version
#define retro_get_system_info             mgba_retro_get_system_info
#define retro_get_system_av_info          mgba_retro_get_system_av_info
#define retro_set_environment            mgba_retro_set_environment
#define retro_set_video_refresh           mgba_retro_set_video_refresh
#define retro_set_audio_sample            mgba_retro_set_audio_sample
#define retro_set_audio_sample_batch      mgba_retro_set_audio_sample_batch
#define retro_set_input_poll              mgba_retro_set_input_poll
#define retro_set_input_state             mgba_retro_set_input_state
#define retro_set_controller_port_device  mgba_retro_set_controller_port_device
#define retro_reset                      mgba_retro_reset
#define retro_run                        mgba_retro_run
#define retro_serialize_size              mgba_retro_serialize_size
#define retro_serialize                  mgba_retro_serialize
#define retro_unserialize                mgba_retro_unserialize
#define retro_cheat_reset                mgba_retro_cheat_reset
#define retro_cheat_set                  mgba_retro_cheat_set
#define retro_load_game                  mgba_retro_load_game
#define retro_load_game_special           mgba_retro_load_game_special
#define retro_unload_game                mgba_retro_unload_game
#define retro_get_region                 mgba_retro_get_region
#define retro_get_memory_data             mgba_retro_get_memory_data
#define retro_get_memory_size             mgba_retro_get_memory_size


/* Same per-language option-array collision already seen between Genesis Plus GX and
   Nestopia and their own copies of the libretro core-options template: arrays named
   option_defs_XX, options_XX and option_cats_XX per language code. mGBA has the same
   convention, and since Genesis Plus GX (the first core added) was never namespaced for this
   pattern -- nothing existed yet to collide with -- renaming mGBA copies here is the
   minimal-risk fix, rather than reopening that already-verified target. Generated from the
   actual linker output, not hand-typed. */
#define option_cats_ar mgba_lrc_option_cats_ar
#define option_cats_ast mgba_lrc_option_cats_ast
#define option_cats_ca mgba_lrc_option_cats_ca
#define option_cats_chs mgba_lrc_option_cats_chs
#define option_cats_cht mgba_lrc_option_cats_cht
#define option_cats_cs mgba_lrc_option_cats_cs
#define option_cats_cy mgba_lrc_option_cats_cy
#define option_cats_da mgba_lrc_option_cats_da
#define option_cats_de mgba_lrc_option_cats_de
#define option_cats_el mgba_lrc_option_cats_el
#define option_cats_en mgba_lrc_option_cats_en
#define option_cats_eo mgba_lrc_option_cats_eo
#define option_cats_es mgba_lrc_option_cats_es
#define option_cats_fa mgba_lrc_option_cats_fa
#define option_cats_fi mgba_lrc_option_cats_fi
#define option_cats_fr mgba_lrc_option_cats_fr
#define option_cats_gl mgba_lrc_option_cats_gl
#define option_cats_he mgba_lrc_option_cats_he
#define option_cats_hr mgba_lrc_option_cats_hr
#define option_cats_hu mgba_lrc_option_cats_hu
#define option_cats_id mgba_lrc_option_cats_id
#define option_cats_it mgba_lrc_option_cats_it
#define option_cats_ja mgba_lrc_option_cats_ja
#define option_cats_ko mgba_lrc_option_cats_ko
#define option_cats_nl mgba_lrc_option_cats_nl
#define option_cats_no mgba_lrc_option_cats_no
#define option_cats_pl mgba_lrc_option_cats_pl
#define option_cats_pt_br mgba_lrc_option_cats_pt_br
#define option_cats_pt_pt mgba_lrc_option_cats_pt_pt
#define option_cats_ru mgba_lrc_option_cats_ru
#define option_cats_sk mgba_lrc_option_cats_sk
#define option_cats_sr mgba_lrc_option_cats_sr
#define option_cats_sv mgba_lrc_option_cats_sv
#define option_cats_tr mgba_lrc_option_cats_tr
#define option_cats_uk mgba_lrc_option_cats_uk
#define option_cats_us mgba_lrc_option_cats_us
#define option_cats_val mgba_lrc_option_cats_val
#define option_cats_vn mgba_lrc_option_cats_vn
#define option_defs_ar mgba_lrc_option_defs_ar
#define option_defs_ast mgba_lrc_option_defs_ast
#define option_defs_ca mgba_lrc_option_defs_ca
#define option_defs_chs mgba_lrc_option_defs_chs
#define option_defs_cht mgba_lrc_option_defs_cht
#define option_defs_cs mgba_lrc_option_defs_cs
#define option_defs_cy mgba_lrc_option_defs_cy
#define option_defs_da mgba_lrc_option_defs_da
#define option_defs_de mgba_lrc_option_defs_de
#define option_defs_el mgba_lrc_option_defs_el
#define option_defs_en mgba_lrc_option_defs_en
#define option_defs_eo mgba_lrc_option_defs_eo
#define option_defs_es mgba_lrc_option_defs_es
#define option_defs_fa mgba_lrc_option_defs_fa
#define option_defs_fi mgba_lrc_option_defs_fi
#define option_defs_fr mgba_lrc_option_defs_fr
#define option_defs_gl mgba_lrc_option_defs_gl
#define option_defs_he mgba_lrc_option_defs_he
#define option_defs_hr mgba_lrc_option_defs_hr
#define option_defs_hu mgba_lrc_option_defs_hu
#define option_defs_id mgba_lrc_option_defs_id
#define option_defs_it mgba_lrc_option_defs_it
#define option_defs_ja mgba_lrc_option_defs_ja
#define option_defs_ko mgba_lrc_option_defs_ko
#define option_defs_nl mgba_lrc_option_defs_nl
#define option_defs_no mgba_lrc_option_defs_no
#define option_defs_pl mgba_lrc_option_defs_pl
#define option_defs_pt_br mgba_lrc_option_defs_pt_br
#define option_defs_pt_pt mgba_lrc_option_defs_pt_pt
#define option_defs_ru mgba_lrc_option_defs_ru
#define option_defs_sk mgba_lrc_option_defs_sk
#define option_defs_sr mgba_lrc_option_defs_sr
#define option_defs_sv mgba_lrc_option_defs_sv
#define option_defs_tr mgba_lrc_option_defs_tr
#define option_defs_uk mgba_lrc_option_defs_uk
#define option_defs_us mgba_lrc_option_defs_us
#define option_defs_val mgba_lrc_option_defs_val
#define option_defs_vn mgba_lrc_option_defs_vn
#define options_ar mgba_lrc_options_ar
#define options_ast mgba_lrc_options_ast
#define options_ca mgba_lrc_options_ca
#define options_chs mgba_lrc_options_chs
#define options_cht mgba_lrc_options_cht
#define options_cs mgba_lrc_options_cs
#define options_cy mgba_lrc_options_cy
#define options_da mgba_lrc_options_da
#define options_de mgba_lrc_options_de
#define options_el mgba_lrc_options_el
#define options_en mgba_lrc_options_en
#define options_eo mgba_lrc_options_eo
#define options_es mgba_lrc_options_es
#define options_fa mgba_lrc_options_fa
#define options_fi mgba_lrc_options_fi
#define options_fr mgba_lrc_options_fr
#define options_gl mgba_lrc_options_gl
#define options_he mgba_lrc_options_he
#define options_hr mgba_lrc_options_hr
#define options_hu mgba_lrc_options_hu
#define options_id mgba_lrc_options_id
#define options_intl mgba_lrc_options_intl
#define options_it mgba_lrc_options_it
#define options_ja mgba_lrc_options_ja
#define options_ko mgba_lrc_options_ko
#define options_nl mgba_lrc_options_nl
#define options_no mgba_lrc_options_no
#define options_pl mgba_lrc_options_pl
#define options_pt_br mgba_lrc_options_pt_br
#define options_pt_pt mgba_lrc_options_pt_pt
#define options_ru mgba_lrc_options_ru
#define options_sk mgba_lrc_options_sk
#define options_sr mgba_lrc_options_sr
#define options_sv mgba_lrc_options_sv
#define options_tr mgba_lrc_options_tr
#define options_uk mgba_lrc_options_uk
#define options_us mgba_lrc_options_us
#define options_val mgba_lrc_options_val
#define options_vn mgba_lrc_options_vn

#include "libretro.h"

#endif
