/*
 * Avalon — frame conversion hot path.
 *
 * Every software core in this repository hands the frontend a raw pixel buffer, and every frontend
 * here converts it badly. Folium builds a CGImage and a UIImage per frame and assigns it to a
 * UIImageView on the main actor (Folium/Folium/Controllers/Emulation/KiwiController.swift:381-408). Mandarine converts the
 * entire 1024x512 PS1 VRAM to a 24-bit CGImage every frame and only then crops to the visible
 * region (MandarineController.swift:340-352, Extensions/CGImage.swift:85-126).
 *
 * This replaces both with a direct conversion into a texture staging buffer: no allocation, no
 * CoreGraphics, and — importantly for the Mandarine case — a region blit that touches only the
 * pixels actually on screen.
 *
 * Output is always BGRA8888 in memory order (B,G,R,A), which is MTLPixelFormatBGRA8Unorm.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef AVALON_PIXEL_H
#define AVALON_PIXEL_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Source layouts emitted by cores in this repository. */
typedef enum {
    AVALON_PIXEL_RGB565   = 0, /* Delta's NES/SNES descriptors */
    AVALON_PIXEL_ABGR1555 = 1, /* PS1 VRAM (bit 15 = mask) */
    AVALON_PIXEL_RGBA8888 = 2,
    AVALON_PIXEL_BGRA8888 = 3  /* already correct; memcpy path */
} avalon_pixel_format;

/* Bytes per pixel for a source format. */
size_t avalon_pixel_stride(avalon_pixel_format fmt);

/*
 * Convert a full frame into BGRA8888.
 * `dst` must hold at least `count` uint32_t. Returns 0 on success, -1 on bad arguments.
 */
int avalon_convert(const void *src, uint32_t *dst, size_t count, avalon_pixel_format fmt);

/*
 * Convert only a sub-rectangle of a larger source surface.
 *
 * This is the Mandarine case: a 1024x512 VRAM surface of which a 320x240 window is visible.
 * Converting the region directly rather than the whole surface is ~6.8x less work for that
 * geometry, and avoids the intermediate image entirely.
 *
 * src_stride_pixels is the source surface's full width in pixels.
 * dst_stride_pixels is the destination's row stride in pixels (>= w), for texture alignment.
 */
int avalon_convert_region(const void *src, size_t src_stride_pixels,
                          uint32_t *dst, size_t dst_stride_pixels,
                          size_t x, size_t y, size_t w, size_t h,
                          avalon_pixel_format fmt);

/* Non-zero if this build took a SIMD path. Reported by Avalon's diagnostics. */
int avalon_pixel_simd_enabled(void);

#ifdef __cplusplus
}
#endif
#endif /* AVALON_PIXEL_H */
