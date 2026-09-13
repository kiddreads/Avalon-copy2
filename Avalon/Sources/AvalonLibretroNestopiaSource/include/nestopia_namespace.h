/* Avalon — namespacing Nestopia's libretro port for static linking.
 *
 * Same technique and reason as genesisplusgx_namespace.h: every RETRO_API entry point Nestopia's
 * libretro.cpp defines is renamed at the preprocessor level, ahead of the vendored, unmodified
 * `Libretro/nestopia/libretro/libretro.cpp`, so two statically-linked cores never collide on a
 * bare `retro_run`.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later (Avalon's own text, this file)
 * Nestopia itself is GPL-2.0-or-later; see NOTICE.md.
 */

#ifndef AVALON_NESTOPIA_NAMESPACE_H
#define AVALON_NESTOPIA_NAMESPACE_H

#define retro_init                       nestopia_retro_init
#define retro_deinit                     nestopia_retro_deinit
#define retro_api_version                nestopia_retro_api_version
#define retro_get_system_info             nestopia_retro_get_system_info
#define retro_get_system_av_info          nestopia_retro_get_system_av_info
#define retro_set_environment            nestopia_retro_set_environment
#define retro_set_video_refresh           nestopia_retro_set_video_refresh
#define retro_set_audio_sample            nestopia_retro_set_audio_sample
#define retro_set_audio_sample_batch      nestopia_retro_set_audio_sample_batch
#define retro_set_input_poll              nestopia_retro_set_input_poll
#define retro_set_input_state             nestopia_retro_set_input_state
#define retro_set_controller_port_device  nestopia_retro_set_controller_port_device
#define retro_reset                      nestopia_retro_reset
#define retro_run                        nestopia_retro_run
#define retro_serialize_size              nestopia_retro_serialize_size
#define retro_serialize                  nestopia_retro_serialize
#define retro_unserialize                nestopia_retro_unserialize
#define retro_cheat_reset                nestopia_retro_cheat_reset
#define retro_cheat_set                  nestopia_retro_cheat_set
#define retro_load_game                  nestopia_retro_load_game
#define retro_load_game_special           nestopia_retro_load_game_special
#define retro_unload_game                nestopia_retro_unload_game
#define retro_get_region                 nestopia_retro_get_region
#define retro_get_memory_data             nestopia_retro_get_memory_data
#define retro_get_memory_size             nestopia_retro_get_memory_size


/* libretro-common is a shared utility library every libretro core vendors its own copy of.
   Nestopia's snapshot and Genesis Plus GX's differ (different years, different internal
   structure), so sharing one copy between them risks silently mixing behaviour from two
   versions -- these 124 externally-linked helper symbols (`filestream_*`, `fill_pathname_*`,
   etc.) are just as bare as the RETRO_API surface above, and collided at link time the moment
   a second core's libretro-common was linked into the same binary. Generated from this
   target's actual compiled .c files, not hand-typed. */
#define c99_snprintf_retro__ nestopia_lrc_c99_snprintf_retro__
#define c99_vsnprintf_retro__ nestopia_lrc_c99_vsnprintf_retro__
#define compat_strcasestr nestopia_lrc_compat_strcasestr
#define filestream_close nestopia_lrc_filestream_close
#define filestream_cmp nestopia_lrc_filestream_cmp
#define filestream_copy nestopia_lrc_filestream_copy
#define filestream_delete nestopia_lrc_filestream_delete
#define filestream_eof nestopia_lrc_filestream_eof
#define filestream_error nestopia_lrc_filestream_error
#define filestream_exists nestopia_lrc_filestream_exists
#define filestream_flush nestopia_lrc_filestream_flush
#define filestream_get_mapped_ptr nestopia_lrc_filestream_get_mapped_ptr
#define filestream_get_size nestopia_lrc_filestream_get_size
#define filestream_getc nestopia_lrc_filestream_getc
#define filestream_getline nestopia_lrc_filestream_getline
#define filestream_matches_buf nestopia_lrc_filestream_matches_buf
#define filestream_printf nestopia_lrc_filestream_printf
#define filestream_putc nestopia_lrc_filestream_putc
#define filestream_read nestopia_lrc_filestream_read
#define filestream_read_file nestopia_lrc_filestream_read_file
#define filestream_rename nestopia_lrc_filestream_rename
#define filestream_rewind nestopia_lrc_filestream_rewind
#define filestream_scanf nestopia_lrc_filestream_scanf
#define filestream_seek nestopia_lrc_filestream_seek
#define filestream_set_mapped_ptr_cb nestopia_lrc_filestream_set_mapped_ptr_cb
#define filestream_tell nestopia_lrc_filestream_tell
#define filestream_truncate nestopia_lrc_filestream_truncate
#define filestream_vfs_init nestopia_lrc_filestream_vfs_init
#define filestream_vprintf nestopia_lrc_filestream_vprintf
#define filestream_vscanf nestopia_lrc_filestream_vscanf
#define filestream_write nestopia_lrc_filestream_write
#define filestream_write_file nestopia_lrc_filestream_write_file
#define fill_dated_filename nestopia_lrc_fill_dated_filename
#define fill_pathname nestopia_lrc_fill_pathname
#define fill_pathname_abbreviate_special nestopia_lrc_fill_pathname_abbreviate_special
#define fill_pathname_abbreviated_or_relative nestopia_lrc_fill_pathname_abbreviated_or_relative
#define fill_pathname_application_dir nestopia_lrc_fill_pathname_application_dir
#define fill_pathname_application_path nestopia_lrc_fill_pathname_application_path
#define fill_pathname_base nestopia_lrc_fill_pathname_base
#define fill_pathname_basedir nestopia_lrc_fill_pathname_basedir
#define fill_pathname_dir nestopia_lrc_fill_pathname_dir
#define fill_pathname_expand_special nestopia_lrc_fill_pathname_expand_special
#define fill_pathname_home_dir nestopia_lrc_fill_pathname_home_dir
#define fill_pathname_join nestopia_lrc_fill_pathname_join
#define fill_pathname_join_delim nestopia_lrc_fill_pathname_join_delim
#define fill_pathname_join_special_ext nestopia_lrc_fill_pathname_join_special_ext
#define fill_pathname_parent_dir nestopia_lrc_fill_pathname_parent_dir
#define fill_pathname_parent_dir_name nestopia_lrc_fill_pathname_parent_dir_name
#define fill_pathname_resolve_relative nestopia_lrc_fill_pathname_resolve_relative
#define fill_pathname_slash nestopia_lrc_fill_pathname_slash
#define fill_str_dated_filename nestopia_lrc_fill_str_dated_filename
#define find_last_slash nestopia_lrc_find_last_slash
#define fopen_utf8 nestopia_lrc_fopen_utf8
#define is_path_accessible_using_standard_io nestopia_lrc_is_path_accessible_using_standard_io
#define local_to_utf8_string nestopia_lrc_local_to_utf8_string
#define local_to_utf8_string_alloc nestopia_lrc_local_to_utf8_string_alloc
#define path_basedir nestopia_lrc_path_basedir
#define path_basedir_wrapper nestopia_lrc_path_basedir_wrapper
#define path_basename nestopia_lrc_path_basename
#define path_basename_nocompression nestopia_lrc_path_basename_nocompression
#define path_get_archive_delim nestopia_lrc_path_get_archive_delim
#define path_get_extension nestopia_lrc_path_get_extension
#define path_get_extension_mutable nestopia_lrc_path_get_extension_mutable
#define path_get_size nestopia_lrc_path_get_size
#define path_is_absolute nestopia_lrc_path_is_absolute
#define path_is_character_special nestopia_lrc_path_is_character_special
#define path_is_compressed_file nestopia_lrc_path_is_compressed_file
#define path_is_directory nestopia_lrc_path_is_directory
#define path_is_valid nestopia_lrc_path_is_valid
#define path_linked_list_add_path nestopia_lrc_path_linked_list_add_path
#define path_linked_list_free nestopia_lrc_path_linked_list_free
#define path_mkdir nestopia_lrc_path_mkdir
#define path_parent_dir nestopia_lrc_path_parent_dir
#define path_relative_to nestopia_lrc_path_relative_to
#define path_remove_extension nestopia_lrc_path_remove_extension
#define path_resolve_realpath nestopia_lrc_path_resolve_realpath
#define path_stat nestopia_lrc_path_stat
#define path_vfs_init nestopia_lrc_path_vfs_init
#define pathname_conform_slashes_to_os nestopia_lrc_pathname_conform_slashes_to_os
#define pathname_make_slashes_portable nestopia_lrc_pathname_make_slashes_portable
#define retro_isblank__ nestopia_lrc_retro_isblank__
#define retro_sleep nestopia_lrc_retro_sleep
#define retro_sleep_us nestopia_lrc_retro_sleep_us
#define retro_strcasecmp__ nestopia_lrc_retro_strcasecmp__
#define retro_strdup__ nestopia_lrc_retro_strdup__
#define retro_strtok_r__ nestopia_lrc_retro_strtok_r__
#define retro_vfs_closedir_impl nestopia_lrc_retro_vfs_closedir_impl
#define retro_vfs_dirent_get_name_impl nestopia_lrc_retro_vfs_dirent_get_name_impl
#define retro_vfs_dirent_is_dir_impl nestopia_lrc_retro_vfs_dirent_is_dir_impl
#define retro_vfs_file_close_impl nestopia_lrc_retro_vfs_file_close_impl
#define retro_vfs_file_error_impl nestopia_lrc_retro_vfs_file_error_impl
#define retro_vfs_file_flush_impl nestopia_lrc_retro_vfs_file_flush_impl
#define retro_vfs_file_get_mapped_ptr_impl nestopia_lrc_retro_vfs_file_get_mapped_ptr_impl
#define retro_vfs_file_get_path_impl nestopia_lrc_retro_vfs_file_get_path_impl
#define retro_vfs_file_open_impl nestopia_lrc_retro_vfs_file_open_impl
#define retro_vfs_file_read_impl nestopia_lrc_retro_vfs_file_read_impl
#define retro_vfs_file_remove_impl nestopia_lrc_retro_vfs_file_remove_impl
#define retro_vfs_file_rename_impl nestopia_lrc_retro_vfs_file_rename_impl
#define retro_vfs_file_seek_impl nestopia_lrc_retro_vfs_file_seek_impl
#define retro_vfs_file_seek_internal nestopia_lrc_retro_vfs_file_seek_internal
#define retro_vfs_file_size_impl nestopia_lrc_retro_vfs_file_size_impl
#define retro_vfs_file_tell_impl nestopia_lrc_retro_vfs_file_tell_impl
#define retro_vfs_file_truncate_impl nestopia_lrc_retro_vfs_file_truncate_impl
#define retro_vfs_file_write_impl nestopia_lrc_retro_vfs_file_write_impl
#define retro_vfs_mkdir_impl nestopia_lrc_retro_vfs_mkdir_impl
#define retro_vfs_opendir_impl nestopia_lrc_retro_vfs_opendir_impl
#define retro_vfs_readdir_impl nestopia_lrc_retro_vfs_readdir_impl
#define retro_vfs_stat_64_impl nestopia_lrc_retro_vfs_stat_64_impl
#define retro_vfs_stat_impl nestopia_lrc_retro_vfs_stat_impl
#define rtime_deinit nestopia_lrc_rtime_deinit
#define rtime_init nestopia_lrc_rtime_init
#define rtime_localtime nestopia_lrc_rtime_localtime
#define sanitize_path_part nestopia_lrc_sanitize_path_part
#define strftime_am_pm nestopia_lrc_strftime_am_pm
/* Guarded out of compat_strl.c on Darwin (#if !(defined(__MACH__) && defined(__APPLE__))) --
   Darwin's own libc already provides these, so leaving them unrenamed lets the call sites
   resolve to the system's copy instead of a symbol nothing on this platform defines. */
#define utf16_conv_utf8 nestopia_lrc_utf16_conv_utf8
#define utf16_to_char_string nestopia_lrc_utf16_to_char_string
#define utf16_to_utf8_string_alloc nestopia_lrc_utf16_to_utf8_string_alloc
#define utf8_conv_utf32 nestopia_lrc_utf8_conv_utf32
#define utf8_to_utf16_string_alloc nestopia_lrc_utf8_to_utf16_string_alloc
#define utf8_walk nestopia_lrc_utf8_walk
#define utf8cpy nestopia_lrc_utf8cpy
#define utf8len nestopia_lrc_utf8len
#define utf8skip nestopia_lrc_utf8skip


/* Missed by the first, .c-file-only scan: per-language option arrays defined directly in
   libretro_core_options.h / _intl.h (not functions, so the earlier function-shaped regex
   never matched them), plus a few filestream.c functions whose multi-line signatures the
   same regex didn't match either. Found by re-running the link and reading what was still
   duplicated, not by re-guessing. */
#define filestream_get_path nestopia_lrc_filestream_get_path
#define filestream_get_vfs_handle nestopia_lrc_filestream_get_vfs_handle
#define filestream_gets nestopia_lrc_filestream_gets
#define filestream_open nestopia_lrc_filestream_open
#define option_cats_ar nestopia_lrc_option_cats_ar
#define option_cats_ast nestopia_lrc_option_cats_ast
#define option_cats_be nestopia_lrc_option_cats_be
#define option_cats_bg nestopia_lrc_option_cats_bg
#define option_cats_ca nestopia_lrc_option_cats_ca
#define option_cats_chs nestopia_lrc_option_cats_chs
#define option_cats_cht nestopia_lrc_option_cats_cht
#define option_cats_cs nestopia_lrc_option_cats_cs
#define option_cats_cy nestopia_lrc_option_cats_cy
#define option_cats_da nestopia_lrc_option_cats_da
#define option_cats_de nestopia_lrc_option_cats_de
#define option_cats_el nestopia_lrc_option_cats_el
#define option_cats_en nestopia_lrc_option_cats_en
#define option_cats_eo nestopia_lrc_option_cats_eo
#define option_cats_es nestopia_lrc_option_cats_es
#define option_cats_fa nestopia_lrc_option_cats_fa
#define option_cats_fi nestopia_lrc_option_cats_fi
#define option_cats_fr nestopia_lrc_option_cats_fr
#define option_cats_ga nestopia_lrc_option_cats_ga
#define option_cats_gl nestopia_lrc_option_cats_gl
#define option_cats_he nestopia_lrc_option_cats_he
#define option_cats_hr nestopia_lrc_option_cats_hr
#define option_cats_hu nestopia_lrc_option_cats_hu
#define option_cats_id nestopia_lrc_option_cats_id
#define option_cats_it nestopia_lrc_option_cats_it
#define option_cats_ja nestopia_lrc_option_cats_ja
#define option_cats_ko nestopia_lrc_option_cats_ko
#define option_cats_nl nestopia_lrc_option_cats_nl
#define option_cats_no nestopia_lrc_option_cats_no
#define option_cats_or nestopia_lrc_option_cats_or
#define option_cats_pl nestopia_lrc_option_cats_pl
#define option_cats_pt_br nestopia_lrc_option_cats_pt_br
#define option_cats_pt_pt nestopia_lrc_option_cats_pt_pt
#define option_cats_ru nestopia_lrc_option_cats_ru
#define option_cats_sk nestopia_lrc_option_cats_sk
#define option_cats_sr nestopia_lrc_option_cats_sr
#define option_cats_sv nestopia_lrc_option_cats_sv
#define option_cats_th nestopia_lrc_option_cats_th
#define option_cats_tr nestopia_lrc_option_cats_tr
#define option_cats_tt nestopia_lrc_option_cats_tt
#define option_cats_uk nestopia_lrc_option_cats_uk
#define option_cats_us nestopia_lrc_option_cats_us
#define option_cats_val nestopia_lrc_option_cats_val
#define option_cats_vn nestopia_lrc_option_cats_vn
#define option_defs_ar nestopia_lrc_option_defs_ar
#define option_defs_ast nestopia_lrc_option_defs_ast
#define option_defs_be nestopia_lrc_option_defs_be
#define option_defs_bg nestopia_lrc_option_defs_bg
#define option_defs_ca nestopia_lrc_option_defs_ca
#define option_defs_chs nestopia_lrc_option_defs_chs
#define option_defs_cht nestopia_lrc_option_defs_cht
#define option_defs_cs nestopia_lrc_option_defs_cs
#define option_defs_cy nestopia_lrc_option_defs_cy
#define option_defs_da nestopia_lrc_option_defs_da
#define option_defs_de nestopia_lrc_option_defs_de
#define option_defs_el nestopia_lrc_option_defs_el
#define option_defs_en nestopia_lrc_option_defs_en
#define option_defs_eo nestopia_lrc_option_defs_eo
#define option_defs_es nestopia_lrc_option_defs_es
#define option_defs_fa nestopia_lrc_option_defs_fa
#define option_defs_fi nestopia_lrc_option_defs_fi
#define option_defs_fr nestopia_lrc_option_defs_fr
#define option_defs_ga nestopia_lrc_option_defs_ga
#define option_defs_gl nestopia_lrc_option_defs_gl
#define option_defs_he nestopia_lrc_option_defs_he
#define option_defs_hr nestopia_lrc_option_defs_hr
#define option_defs_hu nestopia_lrc_option_defs_hu
#define option_defs_id nestopia_lrc_option_defs_id
#define option_defs_it nestopia_lrc_option_defs_it
#define option_defs_ja nestopia_lrc_option_defs_ja
#define option_defs_ko nestopia_lrc_option_defs_ko
#define option_defs_nl nestopia_lrc_option_defs_nl
#define option_defs_no nestopia_lrc_option_defs_no
#define option_defs_or nestopia_lrc_option_defs_or
#define option_defs_pl nestopia_lrc_option_defs_pl
#define option_defs_pt_br nestopia_lrc_option_defs_pt_br
#define option_defs_pt_pt nestopia_lrc_option_defs_pt_pt
#define option_defs_ru nestopia_lrc_option_defs_ru
#define option_defs_sk nestopia_lrc_option_defs_sk
#define option_defs_sr nestopia_lrc_option_defs_sr
#define option_defs_sv nestopia_lrc_option_defs_sv
#define option_defs_th nestopia_lrc_option_defs_th
#define option_defs_tr nestopia_lrc_option_defs_tr
#define option_defs_tt nestopia_lrc_option_defs_tt
#define option_defs_uk nestopia_lrc_option_defs_uk
#define option_defs_us nestopia_lrc_option_defs_us
#define option_defs_val nestopia_lrc_option_defs_val
#define option_defs_vn nestopia_lrc_option_defs_vn
#define options_ar nestopia_lrc_options_ar
#define options_ast nestopia_lrc_options_ast
#define options_be nestopia_lrc_options_be
#define options_bg nestopia_lrc_options_bg
#define options_ca nestopia_lrc_options_ca
#define options_chs nestopia_lrc_options_chs
#define options_cht nestopia_lrc_options_cht
#define options_cs nestopia_lrc_options_cs
#define options_cy nestopia_lrc_options_cy
#define options_da nestopia_lrc_options_da
#define options_de nestopia_lrc_options_de
#define options_el nestopia_lrc_options_el
#define options_en nestopia_lrc_options_en
#define options_eo nestopia_lrc_options_eo
#define options_es nestopia_lrc_options_es
#define options_fa nestopia_lrc_options_fa
#define options_fi nestopia_lrc_options_fi
#define options_fr nestopia_lrc_options_fr
#define options_ga nestopia_lrc_options_ga
#define options_gl nestopia_lrc_options_gl
#define options_he nestopia_lrc_options_he
#define options_hr nestopia_lrc_options_hr
#define options_hu nestopia_lrc_options_hu
#define options_id nestopia_lrc_options_id
#define options_intl nestopia_lrc_options_intl
#define options_it nestopia_lrc_options_it
#define options_ja nestopia_lrc_options_ja
#define options_ko nestopia_lrc_options_ko
#define options_nl nestopia_lrc_options_nl
#define options_no nestopia_lrc_options_no
#define options_or nestopia_lrc_options_or
#define options_pl nestopia_lrc_options_pl
#define options_pt_br nestopia_lrc_options_pt_br
#define options_pt_pt nestopia_lrc_options_pt_pt
#define options_ru nestopia_lrc_options_ru
#define options_sk nestopia_lrc_options_sk
#define options_sr nestopia_lrc_options_sr
#define options_sv nestopia_lrc_options_sv
#define options_th nestopia_lrc_options_th
#define options_tr nestopia_lrc_options_tr
#define options_tt nestopia_lrc_options_tt
#define options_uk nestopia_lrc_options_uk
#define options_us nestopia_lrc_options_us
#define options_val nestopia_lrc_options_val
#define options_vn nestopia_lrc_options_vn
#define utf8_to_local_string_alloc nestopia_lrc_utf8_to_local_string_alloc

#include "libretro.h"

#endif
