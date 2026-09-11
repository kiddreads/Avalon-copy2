/* SPDX-License-Identifier: AGPL-3.0-or-later */
#include "include/AvalonPixel.h"
#include <string.h>

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#define AVALON_NEON 1
#else
#define AVALON_NEON 0
#endif

int avalon_pixel_simd_enabled(void) { return AVALON_NEON; }

size_t avalon_pixel_stride(avalon_pixel_format fmt) {
    switch (fmt) {
        case AVALON_PIXEL_RGB565:
        case AVALON_PIXEL_ABGR1555: return 2;
        case AVALON_PIXEL_RGBA8888:
        case AVALON_PIXEL_BGRA8888: return 4;
    }
    return 0;
}

/* 5- and 6-bit channels are bit-replicated, not shifted: 0x1F must map to 0xFF, not 0xF8.
   Plain shifting darkens every frame by up to 3%, which is the classic emulator washed-out look. */
static inline uint32_t rgb565_to_bgra(uint16_t p) {
    uint32_t r5 = (p >> 11) & 0x1Fu, g6 = (p >> 5) & 0x3Fu, b5 = p & 0x1Fu;
    uint32_t r = (r5 << 3) | (r5 >> 2);
    uint32_t g = (g6 << 2) | (g6 >> 4);
    uint32_t b = (b5 << 3) | (b5 >> 2);
    return 0xFF000000u | (r << 16) | (g << 8) | b;
}

static inline uint32_t abgr1555_to_bgra(uint16_t p) {
    uint32_t b5 = (p >> 10) & 0x1Fu, g5 = (p >> 5) & 0x1Fu, r5 = p & 0x1Fu;
    uint32_t r = (r5 << 3) | (r5 >> 2);
    uint32_t g = (g5 << 3) | (g5 >> 2);
    uint32_t b = (b5 << 3) | (b5 >> 2);
    return 0xFF000000u | (r << 16) | (g << 8) | b;
}

static inline uint32_t rgba_to_bgra(uint32_t p) {
    /* RGBA in memory (R,G,B,A) -> BGRA in memory (B,G,R,A): swap R and B. */
    return (p & 0xFF00FF00u) | ((p & 0x00FF0000u) >> 16) | ((p & 0x000000FFu) << 16);
}

static void convert_rgb565(const uint16_t *src, uint32_t *dst, size_t n) {
    size_t i = 0;
#if AVALON_NEON
    for (; i + 8 <= n; i += 8) {
        uint16x8_t p = vld1q_u16(src + i);
        uint16x8_t r5 = vshrq_n_u16(p, 11);
        uint16x8_t g6 = vandq_u16(vshrq_n_u16(p, 5), vdupq_n_u16(0x3F));
        uint16x8_t b5 = vandq_u16(p, vdupq_n_u16(0x1F));
        uint8x8_t r = vmovn_u16(vorrq_u16(vshlq_n_u16(r5, 3), vshrq_n_u16(r5, 2)));
        uint8x8_t g = vmovn_u16(vorrq_u16(vshlq_n_u16(g6, 2), vshrq_n_u16(g6, 4)));
        uint8x8_t b = vmovn_u16(vorrq_u16(vshlq_n_u16(b5, 3), vshrq_n_u16(b5, 2)));
        uint8x8x4_t out; out.val[0] = b; out.val[1] = g; out.val[2] = r; out.val[3] = vdup_n_u8(0xFF);
        vst4_u8((uint8_t *)(dst + i), out);
    }
#endif
    for (; i < n; ++i) dst[i] = rgb565_to_bgra(src[i]);
}

static void convert_abgr1555(const uint16_t *src, uint32_t *dst, size_t n) {
    size_t i = 0;
#if AVALON_NEON
    for (; i + 8 <= n; i += 8) {
        uint16x8_t p = vld1q_u16(src + i);
        uint16x8_t b5 = vandq_u16(vshrq_n_u16(p, 10), vdupq_n_u16(0x1F));
        uint16x8_t g5 = vandq_u16(vshrq_n_u16(p, 5), vdupq_n_u16(0x1F));
        uint16x8_t r5 = vandq_u16(p, vdupq_n_u16(0x1F));
        uint8x8_t r = vmovn_u16(vorrq_u16(vshlq_n_u16(r5, 3), vshrq_n_u16(r5, 2)));
        uint8x8_t g = vmovn_u16(vorrq_u16(vshlq_n_u16(g5, 3), vshrq_n_u16(g5, 2)));
        uint8x8_t b = vmovn_u16(vorrq_u16(vshlq_n_u16(b5, 3), vshrq_n_u16(b5, 2)));
        uint8x8x4_t out; out.val[0] = b; out.val[1] = g; out.val[2] = r; out.val[3] = vdup_n_u8(0xFF);
        vst4_u8((uint8_t *)(dst + i), out);
    }
#endif
    for (; i < n; ++i) dst[i] = abgr1555_to_bgra(src[i]);
}

static void convert_rgba(const uint32_t *src, uint32_t *dst, size_t n) {
    size_t i = 0;
#if AVALON_NEON
    for (; i + 16 <= n; i += 16) {
        uint8x16x4_t px = vld4q_u8((const uint8_t *)(src + i)); /* R,G,B,A planes */
        uint8x16x4_t out;
        out.val[0] = px.val[2]; out.val[1] = px.val[1];
        out.val[2] = px.val[0]; out.val[3] = px.val[3];
        vst4q_u8((uint8_t *)(dst + i), out);
    }
#endif
    for (; i < n; ++i) dst[i] = rgba_to_bgra(src[i]);
}

int avalon_convert(const void *src, uint32_t *dst, size_t count, avalon_pixel_format fmt) {
    if (!src || !dst) return -1;
    if (count == 0) return 0;
    switch (fmt) {
        case AVALON_PIXEL_RGB565:   convert_rgb565((const uint16_t *)src, dst, count); return 0;
        case AVALON_PIXEL_ABGR1555: convert_abgr1555((const uint16_t *)src, dst, count); return 0;
        case AVALON_PIXEL_RGBA8888: convert_rgba((const uint32_t *)src, dst, count); return 0;
        case AVALON_PIXEL_BGRA8888: memcpy(dst, src, count * 4); return 0;
    }
    return -1;
}

int avalon_convert_region(const void *src, size_t src_stride_pixels,
                          uint32_t *dst, size_t dst_stride_pixels,
                          size_t x, size_t y, size_t w, size_t h,
                          avalon_pixel_format fmt) {
    if (!src || !dst) return -1;
    if (w == 0 || h == 0) return 0;
    if (dst_stride_pixels < w) return -1;
    if (x + w > src_stride_pixels) return -1;

    const size_t bpp = avalon_pixel_stride(fmt);
    if (bpp == 0) return -1;
    const uint8_t *base = (const uint8_t *)src;

    for (size_t row = 0; row < h; ++row) {
        const void *srow = base + ((y + row) * src_stride_pixels + x) * bpp;
        uint32_t *drow = dst + row * dst_stride_pixels;
        int rc = avalon_convert(srow, drow, w, fmt);
        if (rc != 0) return rc;
    }
    return 0;
}
