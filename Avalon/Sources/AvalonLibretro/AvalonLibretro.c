/* Avalon — the libretro frontend.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#include "include/AvalonLibretro.h"
#include <stdlib.h>
#include <string.h>

#define AVALON_MAX_PORTS 4

struct avalon_libretro_session {
    const avalon_libretro_vtable *v;

    char *system_directory;
    char *save_directory;

    struct retro_system_info sys;
    struct retro_system_av_info av;

    enum retro_pixel_format format;

    avalon_libretro_frame frame;
    int have_frame;

    /* libretro's RETRO_PIXEL_FORMAT_0RGB1555 is bit14-10=R, 9-5=G, 4-0=B (bit 15 unused).
       Avalon's .abgr1555 (AvalonPixel.c's convert_abgr1555) is bit14-10=B, 9-5=G, 4-0=R. The
       formats are NOT the same value with a different name -- R and B are swapped -- so a core
       that negotiates 0RGB1555 needs an actual conversion, not a relabel. That is the one format
       this frontend cannot hand through zero-copy; the scratch buffer holds the swapped frame. */
    uint16_t *swap_scratch;
    size_t swap_scratch_pixels;

    avalon_libretro_audio_cb audio_cb;
    void *audio_ctx;

    int16_t buttons[AVALON_MAX_PORTS][16];
    int16_t analog[AVALON_MAX_PORTS][2][2];

    int loaded;
};

/* libretro hands out bare function pointers with no context argument, so the running session has
   to be reachable from a global. One core runs at a time by construction — the vtable exists
   precisely because a process cannot host two cores that both export `retro_run` — so a single
   slot is the honest model rather than a limitation worth hiding. */
static avalon_libretro_session *g_active = NULL;

/* --- callbacks the core calls into ------------------------------------- */

static void swap_0rgb1555_to_abgr1555(const uint16_t *src, uint16_t *dst, size_t n) {
    for (size_t i = 0; i < n; i++) {
        uint16_t p = src[i];
        uint16_t r = (p >> 10) & 0x1Fu, g = (p >> 5) & 0x1Fu, b = p & 0x1Fu;
        dst[i] = (uint16_t)((b << 10) | (g << 5) | r);
    }
}

static void cb_video(const void *data, unsigned width, unsigned height, size_t pitch) {
    avalon_libretro_session *s = g_active;
    if (!s) return;
    if (data == NULL) {
        /* A NULL frame means "identical to the last one". Reporting it rather than dropping it
           lets the presenter skip work instead of re-uploading an unchanged texture. */
        s->frame.frame_was_duped = 1;
        return;
    }

    if (s->format == RETRO_PIXEL_FORMAT_0RGB1555) {
        size_t stride_pixels = pitch / sizeof(uint16_t);
        size_t needed = stride_pixels * height;
        if (needed > s->swap_scratch_pixels) {
            uint16_t *grown = (uint16_t *)realloc(s->swap_scratch, needed * sizeof(uint16_t));
            if (!grown) { s->frame.frame_was_duped = 1; return; }   /* drop rather than corrupt */
            s->swap_scratch = grown;
            s->swap_scratch_pixels = needed;
        }
        swap_0rgb1555_to_abgr1555((const uint16_t *)data, s->swap_scratch, needed);
        s->frame.pixels = s->swap_scratch;
    } else {
        s->frame.pixels = data;
    }

    s->frame.width = width;
    s->frame.height = height;
    s->frame.pitch = pitch;
    s->frame.format = s->format;
    s->frame.frame_was_duped = 0;
    s->have_frame = 1;
}

static size_t cb_audio_batch(const int16_t *data, size_t frames) {
    avalon_libretro_session *s = g_active;
    if (s && s->audio_cb && data && frames) s->audio_cb(s->audio_ctx, data, frames);
    return frames;
}

static void cb_audio_sample(int16_t left, int16_t right) {
    int16_t pair[2] = { left, right };
    cb_audio_batch(pair, 1);
}

static void cb_input_poll(void) { /* state is pushed in, so there is nothing to pull */ }

static int16_t cb_input_state(unsigned port, unsigned device, unsigned index, unsigned id) {
    avalon_libretro_session *s = g_active;
    if (!s || port >= AVALON_MAX_PORTS) return 0;

    switch (device) {
        case RETRO_DEVICE_JOYPAD:
            return id < 16 ? s->buttons[port][id] : 0;
        case RETRO_DEVICE_ANALOG:
            if (index < 2 && id < 2) return s->analog[port][index][id];
            return 0;
        default:
            return 0;
    }
}

static bool cb_environment(unsigned cmd, void *data) {
    avalon_libretro_session *s = g_active;

    switch (cmd) {
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            if (!s || !data) return false;
            enum retro_pixel_format fmt = *(const enum retro_pixel_format *)data;
            /* Avalon's presenter converts 0RGB1555, RGB565 and XRGB8888. Anything else would be
               accepted here and then silently mis-rendered, so refuse it instead. */
            if (fmt != RETRO_PIXEL_FORMAT_0RGB1555 &&
                fmt != RETRO_PIXEL_FORMAT_RGB565 &&
                fmt != RETRO_PIXEL_FORMAT_XRGB8888) return false;
            s->format = fmt;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
            if (!s || !data) return false;
            *(const char **)data = s->system_directory;
            return s->system_directory != NULL;

        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            if (!s || !data) return false;
            *(const char **)data = s->save_directory;
            return s->save_directory != NULL;

        case RETRO_ENVIRONMENT_GET_CAN_DUPE:
            if (!data) return false;
            *(bool *)data = true;
            return true;

        case RETRO_ENVIRONMENT_GET_OVERSCAN:
            if (!data) return false;
            *(bool *)data = false;
            return true;

        case RETRO_ENVIRONMENT_SET_VARIABLES:
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS:
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
            /* Core options are accepted and left at their defaults for now. Returning true is
               correct: the core asked whether the frontend understood, not whether it changed
               anything. */
            return true;

        case RETRO_ENVIRONMENT_GET_VARIABLE:
            if (!data) return false;
            ((struct retro_variable *)data)->value = NULL;
            return false;

        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
            if (!data) return false;
            *(bool *)data = false;
            return true;

        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_SUPPORT_ACHIEVEMENTS:
        case RETRO_ENVIRONMENT_SET_MEMORY_MAPS:
        case RETRO_ENVIRONMENT_SET_GEOMETRY:
            return true;

        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
            return true;

        default:
            /* Unknown commands must report false so the core takes its fallback path. Claiming
               support for something unimplemented is how a frontend produces bugs that look like
               core bugs. */
            return false;
    }
}

/* --- lifecycle ---------------------------------------------------------- */

static char *dup_or_null(const char *s) {
    if (!s) return NULL;
    size_t n = strlen(s) + 1;
    char *out = (char *)malloc(n);
    if (out) memcpy(out, s, n);
    return out;
}

avalon_libretro_session *avalon_libretro_open(const avalon_libretro_vtable *vtable,
                                              const char *system_directory,
                                              const char *save_directory) {
    if (!vtable || !vtable->run || !vtable->load_game || !vtable->init) return NULL;
    if (g_active) return NULL;   /* one at a time, and say so rather than corrupt both */

    avalon_libretro_session *s = (avalon_libretro_session *)calloc(1, sizeof *s);
    if (!s) return NULL;

    s->v = vtable;
    s->system_directory = dup_or_null(system_directory);
    s->save_directory = dup_or_null(save_directory);
    s->format = RETRO_PIXEL_FORMAT_0RGB1555;   /* libretro's documented default */

    g_active = s;

    vtable->set_environment(cb_environment);
    vtable->init();
    if (vtable->set_video_refresh) vtable->set_video_refresh(cb_video);
    if (vtable->set_audio_sample) vtable->set_audio_sample(cb_audio_sample);
    if (vtable->set_audio_sample_batch) vtable->set_audio_sample_batch(cb_audio_batch);
    if (vtable->set_input_poll) vtable->set_input_poll(cb_input_poll);
    if (vtable->set_input_state) vtable->set_input_state(cb_input_state);
    if (vtable->get_system_info) vtable->get_system_info(&s->sys);

    return s;
}

void avalon_libretro_close(avalon_libretro_session *s) {
    if (!s) return;
    if (s->loaded && s->v->unload_game) s->v->unload_game();
    if (s->v->deinit) s->v->deinit();
    if (g_active == s) g_active = NULL;
    free(s->system_directory);
    free(s->save_directory);
    free(s->swap_scratch);
    free(s);
}

bool avalon_libretro_load(avalon_libretro_session *s, const char *path,
                          const void *data, size_t size) {
    if (!s || s->loaded) return false;
    struct retro_game_info info;
    memset(&info, 0, sizeof info);
    info.path = path;
    info.data = data;
    info.size = size;
    info.meta = NULL;

    if (!s->v->load_game(&info)) return false;
    s->loaded = 1;
    if (s->v->get_system_av_info) s->v->get_system_av_info(&s->av);
    return true;
}

void avalon_libretro_unload(avalon_libretro_session *s) {
    if (!s || !s->loaded) return;
    if (s->v->unload_game) s->v->unload_game();
    s->loaded = 0;
    s->have_frame = 0;
}

void avalon_libretro_run(avalon_libretro_session *s) {
    if (!s || !s->loaded) return;
    s->frame.frame_was_duped = 0;
    g_active = s;
    s->v->run();
}

void avalon_libretro_reset(avalon_libretro_session *s) {
    if (s && s->loaded && s->v->reset) { g_active = s; s->v->reset(); }
}

bool avalon_libretro_last_frame(const avalon_libretro_session *s, avalon_libretro_frame *out) {
    if (!s || !out || !s->have_frame) return false;
    *out = s->frame;
    return true;
}

void avalon_libretro_set_audio(avalon_libretro_session *s,
                               avalon_libretro_audio_cb cb, void *ctx) {
    if (!s) return;
    s->audio_cb = cb;
    s->audio_ctx = ctx;
}

void avalon_libretro_set_button(avalon_libretro_session *s, unsigned port,
                                unsigned id, bool pressed) {
    if (!s || port >= AVALON_MAX_PORTS || id >= 16) return;
    s->buttons[port][id] = pressed ? 1 : 0;
}

void avalon_libretro_set_analog(avalon_libretro_session *s, unsigned port,
                                unsigned index, unsigned id, int16_t value) {
    if (!s || port >= AVALON_MAX_PORTS || index >= 2 || id >= 2) return;
    s->analog[port][index][id] = value;
}

void avalon_libretro_clear_input(avalon_libretro_session *s) {
    if (!s) return;
    memset(s->buttons, 0, sizeof s->buttons);
    memset(s->analog, 0, sizeof s->analog);
}

double avalon_libretro_fps(const avalon_libretro_session *s) {
    return (s && s->av.timing.fps > 0) ? s->av.timing.fps : 60.0;
}
double avalon_libretro_sample_rate(const avalon_libretro_session *s) {
    return (s && s->av.timing.sample_rate > 0) ? s->av.timing.sample_rate : 48000.0;
}
unsigned avalon_libretro_base_width(const avalon_libretro_session *s) {
    return s ? s->av.geometry.base_width : 0;
}
unsigned avalon_libretro_base_height(const avalon_libretro_session *s) {
    return s ? s->av.geometry.base_height : 0;
}
double avalon_libretro_aspect_ratio(const avalon_libretro_session *s) {
    if (!s) return 0;
    if (s->av.geometry.aspect_ratio > 0) return s->av.geometry.aspect_ratio;
    if (s->av.geometry.base_height == 0) return 0;
    return (double)s->av.geometry.base_width / (double)s->av.geometry.base_height;
}
const char *avalon_libretro_library_name(const avalon_libretro_session *s) {
    return (s && s->sys.library_name) ? s->sys.library_name : "";
}
const char *avalon_libretro_library_version(const avalon_libretro_session *s) {
    return (s && s->sys.library_version) ? s->sys.library_version : "";
}
const char *avalon_libretro_valid_extensions(const avalon_libretro_session *s) {
    return (s && s->sys.valid_extensions) ? s->sys.valid_extensions : "";
}
bool avalon_libretro_needs_full_path(const avalon_libretro_session *s) {
    return s ? s->sys.need_fullpath : false;
}

size_t avalon_libretro_serialize_size(avalon_libretro_session *s) {
    if (!s || !s->loaded || !s->v->serialize_size) return 0;
    g_active = s;
    return s->v->serialize_size();
}
bool avalon_libretro_serialize(avalon_libretro_session *s, void *dest, size_t size) {
    if (!s || !s->loaded || !s->v->serialize) return false;
    g_active = s;
    return s->v->serialize(dest, size);
}
bool avalon_libretro_unserialize(avalon_libretro_session *s, const void *src, size_t size) {
    if (!s || !s->loaded || !s->v->unserialize) return false;
    g_active = s;
    return s->v->unserialize(src, size);
}

void *avalon_libretro_sram(avalon_libretro_session *s, size_t *size_out) {
    if (!s || !s->loaded || !s->v->get_memory_data || !s->v->get_memory_size) return NULL;
    g_active = s;
    size_t n = s->v->get_memory_size(RETRO_MEMORY_SAVE_RAM);
    if (size_out) *size_out = n;
    return n ? s->v->get_memory_data(RETRO_MEMORY_SAVE_RAM) : NULL;
}
