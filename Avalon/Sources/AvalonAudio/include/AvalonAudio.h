/*
 * Avalon — audio resampling and mixing.
 *
 * ADAPTED FROM: Dolphin Emulator Project, AudioCommon/Mixer.{h,cpp} (Copyright 2009 Dolphin
 * Emulator Project, SPDX GPL-2.0-or-later). The same code reached PPSSPP as Core/HW/GranularMixer.*;
 * it is taken here from Dolphin, which is the original.
 *
 * The interpolation kernel is the 6-point, 3rd-order Hermite from Olli Niemitalo, "Polynomial
 * Interpolators for High-Quality Resampling of Oversampled Audio" (2001), page 43.
 *
 * Why this one, of the three mixers in this repository: PPSSPP's shipping default (StereoResampler)
 * is two-tap linear interpolation whose drift correction *pitch-bends by up to ±1.36%* — audible on
 * any sustained tone — and which drops a whole 64-sample block on overrun. The granular design
 * corrects rate by varying how fast it walks the granule queue instead, so pitch stays fixed.
 *
 * What is Avalon's rather than inherited: the guest-emulator coupling is gone (no Config, no
 * logging, no globals), the queue is an explicit ring the caller owns, and rate control is a pure
 * function of queue depth so it can be tested without an audio device.
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

#ifndef AVALON_AUDIO_H
#define AVALON_AUDIO_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 50%-overlapped granules, as in the source design. */
#define AVALON_GRANULE_SIZE     256u
#define AVALON_GRANULE_OVERLAP  (AVALON_GRANULE_SIZE / 2u)
#define AVALON_GRANULE_MASK     (AVALON_GRANULE_SIZE - 1u)
#define AVALON_GRANULE_BITS     8u
#define AVALON_GRANULE_FRAC_BITS (32u - AVALON_GRANULE_BITS)
#define AVALON_MAX_QUEUE        256u

typedef struct { float l, r; } avalon_stereo;

typedef struct {
    avalon_stereo samples[AVALON_GRANULE_SIZE];
} avalon_granule;

/*
 * Opaque by construction. The granule queue alone is 512 KB, which is far past what may safely be
 * a value type: stack-allocating one overflows an ordinary worker thread's stack and faults with
 * SIGBUS. Callers get a pointer and cannot make that mistake.
 */
typedef struct {
    avalon_granule *queue;        /* heap, AVALON_MAX_QUEUE entries */
    uint32_t head, tail;          /* producer / consumer indices */
    uint32_t queue_capacity;      /* target depth, clamped to AVALON_MAX_QUEUE */

    avalon_granule front, back;   /* the two overlapping granules being read */
    uint32_t current_index;       /* 24.8-style fixed point walk position */

    avalon_granule staging;       /* partially filled granule from the producer */
    uint32_t staged;

    float volume;                 /* 0..1 */
    float fade;                   /* click suppression on underrun */
    double input_rate, output_rate;
} avalon_mixer;

/* Create and destroy. Returns NULL on allocation failure. */
avalon_mixer *avalon_mixer_create(double input_rate, double output_rate,
                                  uint32_t target_queue_granules);
void avalon_mixer_destroy(avalon_mixer *m);

/* Producer: push interleaved stereo int16 from the core. Returns frames accepted. */
size_t avalon_mixer_push_s16(avalon_mixer *m, const int16_t *frames, size_t frame_count);

/* Consumer: pull interleaved stereo float. Returns frames written (always `frame_count`;
   underruns are filled by fading rather than by clicking). */
size_t avalon_mixer_pull_f32(avalon_mixer *m, float *out, size_t frame_count);

/* Frames currently buffered, for diagnostics and for the rate controller. */
size_t avalon_mixer_queued_frames(const avalon_mixer *m);

/*
 * The rate the consumer should walk the queue at, given how full it is.
 *
 * This is the part that replaces pitch bending: instead of detuning the audio to absorb drift, the
 * playback step is nudged within a narrow band so the queue converges on its target depth. Pure
 * function so it is testable without a device.
 */
double avalon_mixer_rate_control(double nominal_ratio, size_t queued, size_t target,
                                 double max_adjust);

/* 6-point 3rd-order Hermite evaluated at t in [0,1) across s0..s5. */
float avalon_hermite6(const float s[6], float t);

#ifdef __cplusplus
}
#endif
#endif
