/* SPDX-License-Identifier: AGPL-3.0-or-later
 * Adapted from Dolphin Emulator Project AudioCommon/Mixer.cpp (GPL-2.0-or-later).
 * Hermite kernel: Olli Niemitalo, "Polynomial Interpolators for High-Quality Resampling of
 * Oversampled Audio" (2001), p.43. */
#include "include/AvalonAudio.h"
#include <string.h>
#include <stdlib.h>
#include <math.h>

float avalon_hermite6(const float s[6], float t) {
    const float t2 = t * t, t3 = t2 * t;
    return s[0] * ((  0.0f +  1.0f * t -  2.0f * t2 + 1.0f * t3) / 12.0f)
         + s[1] * ((  0.0f -  8.0f * t + 15.0f * t2 - 7.0f * t3) / 12.0f)
         + s[2] * ((  3.0f +  0.0f * t -  7.0f * t2 + 4.0f * t3) /  3.0f)
         + s[3] * ((  0.0f +  2.0f * t +  5.0f * t2 - 4.0f * t3) /  3.0f)
         + s[4] * ((  0.0f -  1.0f * t -  6.0f * t2 + 7.0f * t3) / 12.0f)
         + s[5] * ((  0.0f +  0.0f * t +  1.0f * t2 - 1.0f * t3) / 12.0f);
}

avalon_mixer *avalon_mixer_create(double input_rate, double output_rate,
                                 uint32_t target_queue_granules) {
    avalon_mixer *m = (avalon_mixer *)calloc(1, sizeof *m);
    if (!m) return NULL;
    m->queue = (avalon_granule *)calloc(AVALON_MAX_QUEUE, sizeof(avalon_granule));
    if (!m->queue) { free(m); return NULL; }
    m->input_rate = input_rate > 0 ? input_rate : 44100.0;
    m->output_rate = output_rate > 0 ? output_rate : 48000.0;
    uint32_t t = target_queue_granules ? target_queue_granules : 8;
    if (t < 4) t = 4;
    if (t > AVALON_MAX_QUEUE - 1) t = AVALON_MAX_QUEUE - 1;
    m->queue_capacity = t;
    m->volume = 1.0f;
    m->fade = 0.0f;
    return m;
}

void avalon_mixer_destroy(avalon_mixer *m) {
    if (!m) return;
    free(m->queue);
    free(m);
}

static uint32_t queued_granules(const avalon_mixer *m) {
    return (m->head - m->tail) & (AVALON_MAX_QUEUE - 1);
}

size_t avalon_mixer_queued_frames(const avalon_mixer *m) {
    return (size_t)queued_granules(m) * AVALON_GRANULE_OVERLAP + m->staged;
}

static void commit_staging(avalon_mixer *m) {
    uint32_t next = (m->head + 1) & (AVALON_MAX_QUEUE - 1);
    if (next == m->tail) {
        /* Queue full: drop the oldest granule rather than the newest. Losing the stalest audio is
           less audible than a gap at the play head. */
        m->tail = (m->tail + 1) & (AVALON_MAX_QUEUE - 1);
    }
    m->queue[m->head] = m->staging;
    m->head = next;
    /* 50% overlap: the next granule starts halfway through this one. */
    memmove(m->staging.samples, m->staging.samples + AVALON_GRANULE_OVERLAP,
            AVALON_GRANULE_OVERLAP * sizeof(avalon_stereo));
    m->staged = AVALON_GRANULE_OVERLAP;
}

size_t avalon_mixer_push_s16(avalon_mixer *m, const int16_t *frames, size_t frame_count) {
    for (size_t i = 0; i < frame_count; ++i) {
        m->staging.samples[m->staged].l = frames[i * 2 + 0] / 32768.0f;
        m->staging.samples[m->staged].r = frames[i * 2 + 1] / 32768.0f;
        if (++m->staged >= AVALON_GRANULE_SIZE) commit_staging(m);
    }
    return frame_count;
}

static int dequeue(avalon_mixer *m, avalon_granule *g) {
    if (m->head == m->tail) return 0;
    *g = m->queue[m->tail];
    m->tail = (m->tail + 1) & (AVALON_MAX_QUEUE - 1);
    return 1;
}

double avalon_mixer_rate_control(double nominal_ratio, size_t queued, size_t target,
                                 double max_adjust) {
    if (target == 0) return nominal_ratio;
    /* Proportional correction on fractional queue error, clamped. Walking the queue slightly
       faster or slower changes latency, not pitch — which is the whole point versus a resampler
       that detunes to absorb the same drift. */
    double err = ((double)queued - (double)target) / (double)target;
    if (err > 1.0) err = 1.0;
    if (err < -1.0) err = -1.0;
    double adj = 1.0 + err * max_adjust;
    double lo = 1.0 - max_adjust, hi = 1.0 + max_adjust;
    if (adj < lo) adj = lo;
    if (adj > hi) adj = hi;
    return nominal_ratio * adj;
}

size_t avalon_mixer_pull_f32(avalon_mixer *m, float *out, size_t frame_count) {
    const double nominal = m->input_rate / m->output_rate;
    const double ratio = avalon_mixer_rate_control(nominal,
                                                   avalon_mixer_queued_frames(m),
                                                   (size_t)m->queue_capacity * AVALON_GRANULE_OVERLAP,
                                                   0.01);
    const uint32_t step = (uint32_t)(ratio * (double)(1u << AVALON_GRANULE_FRAC_BITS));

    /* Fade coefficients: ~1 ms attack/release at typical rates, enough to hide a gap without
       audibly ducking real audio. */
    const float fade_in  = 1.0f - expf(-1.0f / (0.001f * (float)m->output_rate));
    const float fade_out = fade_in;

    for (size_t i = 0; i < frame_count; ++i) {
        const uint32_t front_index = m->current_index;
        const uint32_t back_index  = m->current_index + (AVALON_GRANULE_OVERLAP
                                                         << AVALON_GRANULE_FRAC_BITS);
        const uint32_t ft = (front_index >> AVALON_GRANULE_FRAC_BITS) & AVALON_GRANULE_MASK;
        const uint32_t bt = (back_index  >> AVALON_GRANULE_FRAC_BITS) & AVALON_GRANULE_MASK;

        float lf[6], rf[6];
        for (int k = -2; k <= 3; ++k) {
            const uint32_t fi = (ft + (uint32_t)k) & AVALON_GRANULE_MASK;
            const uint32_t bi = (bt + (uint32_t)k) & AVALON_GRANULE_MASK;
            lf[k + 2] = m->front.samples[fi].l + m->back.samples[bi].l;
            rf[k + 2] = m->front.samples[fi].r + m->back.samples[bi].r;
        }

        const uint32_t t_frac = front_index & ((1u << AVALON_GRANULE_FRAC_BITS) - 1u);
        const float t = (float)t_frac / (float)(1u << AVALON_GRANULE_FRAC_BITS);

        float l = avalon_hermite6(lf, t) * 0.5f;   /* two overlapped granules summed */
        float r = avalon_hermite6(rf, t) * 0.5f;

        /* Underrun fades to silence instead of clicking; recovery fades back in. */
        const int starved = (m->head == m->tail && m->staged == 0);
        if (starved) m->fade += fade_out * (0.0f - m->fade);
        else         m->fade += fade_in  * (1.0f - m->fade);

        out[i * 2 + 0] = l * m->volume * m->fade;
        out[i * 2 + 1] = r * m->volume * m->fade;

        const uint32_t before = m->current_index >> AVALON_GRANULE_FRAC_BITS;
        m->current_index += step;
        const uint32_t after = m->current_index >> AVALON_GRANULE_FRAC_BITS;
        if ((before & AVALON_GRANULE_MASK) > (after & AVALON_GRANULE_MASK)) {
            /* Wrapped a granule: rotate front<-back<-queue. */
            m->front = m->back;
            avalon_granule g;
            if (dequeue(m, &g)) m->back = g;
            else memset(&m->back, 0, sizeof m->back);
        }
    }
    return frame_count;
}
