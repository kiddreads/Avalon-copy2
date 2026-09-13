/* Avalon — hosting a libretro core.
 *
 * libretro is the one thing this whole collection was missing: a stable C ABI that hundreds of
 * emulator cores already implement. `libretro.h` carries its own MIT licence, scoped explicitly to
 * the header — "The following license statement only applies to this libretro API header" — so
 * implementing a frontend against it takes on no copyleft from RetroArch, which is GPL-3.0.
 * Avalon needs the API, not the frontend.
 *
 * Two things make this shim necessary rather than calling libretro directly from Swift.
 *
 * First, libretro is a GLOBAL API: a core exports bare `retro_run`, `retro_load_game` and so on,
 * so one process can only link one core unless every core's symbols are namespaced. Cores are
 * therefore reached through a vtable that a namespaced core fills in, not by symbol name. On iOS
 * this is not a preference — arbitrary dylibs cannot be loaded, so cores are statically linked
 * into the app and namespacing is the only way to have more than one.
 *
 * Second, libretro hands the frontend its callbacks as bare C function pointers with no context
 * argument. That means the active core has to be reachable from a global, and doing that in C
 * keeps the unsafety in one small file instead of spreading it through Swift.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef AVALON_LIBRETRO_H
#define AVALON_LIBRETRO_H

#include "libretro.h"
#include <stdbool.h>
#include <stddef.h>

/** Every libretro entry point a frontend needs, as a vtable.
 *
 *  A statically linked core fills this in with its own namespaced symbols. */
typedef struct {
    const char *id;
    void     (*set_environment)(retro_environment_t);
    void     (*set_video_refresh)(retro_video_refresh_t);
    void     (*set_audio_sample)(retro_audio_sample_t);
    void     (*set_audio_sample_batch)(retro_audio_sample_batch_t);
    void     (*set_input_poll)(retro_input_poll_t);
    void     (*set_input_state)(retro_input_state_t);
    void     (*init)(void);
    void     (*deinit)(void);
    unsigned (*api_version)(void);
    void     (*get_system_info)(struct retro_system_info *);
    void     (*get_system_av_info)(struct retro_system_av_info *);
    bool     (*load_game)(const struct retro_game_info *);
    void     (*unload_game)(void);
    void     (*run)(void);
    void     (*reset)(void);
    size_t   (*serialize_size)(void);
    bool     (*serialize)(void *, size_t);
    bool     (*unserialize)(const void *, size_t);
    void    *(*get_memory_data)(unsigned);
    size_t   (*get_memory_size)(unsigned);
} avalon_libretro_vtable;

/** What one frame of a running core produced. Owned by the core; valid until the next `run`. */
typedef struct {
    const void *pixels;
    unsigned width;
    unsigned height;
    size_t pitch;             /**< bytes per row, NOT width * bpp */
    enum retro_pixel_format format;
    int frame_was_duped;      /**< the core passed NULL, meaning "same as last time" */
} avalon_libretro_frame;

typedef struct avalon_libretro_session avalon_libretro_session;

/** Audio the core produced this frame, as interleaved stereo int16. */
typedef void (*avalon_libretro_audio_cb)(void *ctx, const int16_t *frames, size_t frame_count);

avalon_libretro_session *avalon_libretro_open(const avalon_libretro_vtable *vtable,
                                              const char *system_directory,
                                              const char *save_directory);
void avalon_libretro_close(avalon_libretro_session *s);

/** Load a ROM already in memory. libretro cores that need a path get one via `path`. */
bool avalon_libretro_load(avalon_libretro_session *s, const char *path,
                          const void *data, size_t size);
void avalon_libretro_unload(avalon_libretro_session *s);

void avalon_libretro_run(avalon_libretro_session *s);
void avalon_libretro_reset(avalon_libretro_session *s);

/** The most recent frame. Returns false before the first `run`. */
bool avalon_libretro_last_frame(const avalon_libretro_session *s, avalon_libretro_frame *out);

void avalon_libretro_set_audio(avalon_libretro_session *s,
                               avalon_libretro_audio_cb cb, void *ctx);

/** Digital button state, indexed by RETRO_DEVICE_ID_JOYPAD_*. */
void avalon_libretro_set_button(avalon_libretro_session *s, unsigned port,
                                unsigned id, bool pressed);
/** Analog axis, RETRO_DEVICE_INDEX_ANALOG_* and RETRO_DEVICE_ID_ANALOG_*, −0x8000…0x7fff. */
void avalon_libretro_set_analog(avalon_libretro_session *s, unsigned port,
                                unsigned index, unsigned id, int16_t value);
void avalon_libretro_clear_input(avalon_libretro_session *s);

double avalon_libretro_fps(const avalon_libretro_session *s);
double avalon_libretro_sample_rate(const avalon_libretro_session *s);
unsigned avalon_libretro_base_width(const avalon_libretro_session *s);
unsigned avalon_libretro_base_height(const avalon_libretro_session *s);
double avalon_libretro_aspect_ratio(const avalon_libretro_session *s);
const char *avalon_libretro_library_name(const avalon_libretro_session *s);
const char *avalon_libretro_library_version(const avalon_libretro_session *s);
const char *avalon_libretro_valid_extensions(const avalon_libretro_session *s);
bool avalon_libretro_needs_full_path(const avalon_libretro_session *s);

size_t avalon_libretro_serialize_size(avalon_libretro_session *s);
bool avalon_libretro_serialize(avalon_libretro_session *s, void *dest, size_t size);
bool avalon_libretro_unserialize(avalon_libretro_session *s, const void *src, size_t size);

/** Battery-backed save RAM (RETRO_MEMORY_SAVE_RAM), or NULL if the game has none. */
void *avalon_libretro_sram(avalon_libretro_session *s, size_t *size_out);

#endif /* AVALON_LIBRETRO_H */
