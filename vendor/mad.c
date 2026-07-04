/*
 * mach-audio device shim - the sole native translation unit in mach-audio.
 *
 * vendors miniaudio v0.11.25 (https://miniaud.io, dual Unlicense / MIT-0) and
 * exposes a small, ABI-stable surface (`mad_*`) over the ma_device lifecycle
 * ONLY: open, start, stop, close, and the data callback. everything above the
 * callback - mixing, resampling, decoding, effects - is pure Mach and never
 * touches this file.
 *
 * miniaudio's own high-level features (decoders, encoders, generators, resource
 * manager, node graph, engine) are compiled out below and never used; the
 * device's internal format conversion is the only ma_* machinery that stays.
 *
 * the Mach bindings (src/device.mach) call these `mad_*` functions and nothing
 * else, so miniaudio's struct layouts never cross the FFI boundary and a
 * miniaudio version bump cannot break the Mach side.
 *
 * to update miniaudio: replace vendor/miniaudio.h with the new single header,
 * bump the version in this comment, and rebuild. the shim below only touches
 * documented public ma_device fields.
 */

/* device layer only: exclude miniaudio's decoders, encoders, generators,
 * resource manager, node graph, and high-level engine. */
#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_ENGINE

/* keep every miniaudio symbol internal to this TU; only the mad_* shim is
 * exported, so two libraries embedding miniaudio never collide. */
#define MA_API static

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <stdlib.h>

/* fills `out` with `frames` interleaved f32 frames of `channels` each. runs on
 * miniaudio's high-priority audio thread: must not allocate or lock. */
typedef void (*mad_render_fn)(float *out, unsigned int frames, unsigned int channels, void *user);

/* one open playback device: the ma_device plus the Mach render hook. */
typedef struct {
    ma_device     device;
    mad_render_fn render;
    void         *user;
} mad_device;

/* miniaudio data callback; forwards the output buffer to the Mach render hook.
 * capture input is unused (playback only). */
static void mad__data_callback(ma_device *pDevice, void *pOutput, const void *pInput, ma_uint32 frameCount)
{
    mad_device *d = (mad_device *)pDevice->pUserData;
    (void)pInput;
    if (d != NULL && d->render != NULL) {
        d->render((float *)pOutput, (unsigned int)frameCount, pDevice->playback.channels, d->user);
    }
}

/* open an f32 playback device at the given rate and channel count, driven by
 * `render`. returns an opaque handle, or NULL on allocation or backend failure.
 * a rate or channel count of 0 asks the backend for its native value. */
void *mad_device_open(unsigned int sample_rate, unsigned int channels, mad_render_fn render, void *user)
{
    mad_device *d = (mad_device *)malloc(sizeof(*d));
    if (d == NULL) {
        return NULL;
    }
    d->render = render;
    d->user   = user;

    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format   = ma_format_f32;
    config.playback.channels = channels;
    config.sampleRate        = sample_rate;
    config.dataCallback      = mad__data_callback;
    config.pUserData         = d;

    if (ma_device_init(NULL, &config, &d->device) != MA_SUCCESS) {
        free(d);
        return NULL;
    }
    return d;
}

/* begin pulling from the render hook. returns 0 on success, non-zero otherwise. */
int mad_device_start(void *dev)
{
    if (dev == NULL) {
        return -1;
    }
    return (int)ma_device_start(&((mad_device *)dev)->device);
}

/* stop pulling; the device stays open and can be started again. returns 0 on
 * success, non-zero otherwise. */
int mad_device_stop(void *dev)
{
    if (dev == NULL) {
        return -1;
    }
    return (int)ma_device_stop(&((mad_device *)dev)->device);
}

/* stop and release the device and its handle. safe on NULL. */
void mad_device_close(void *dev)
{
    if (dev == NULL) {
        return;
    }
    ma_device_uninit(&((mad_device *)dev)->device);
    free(dev);
}

/* the rate, in Hz, at which the callback is fed (resolved native rate when 0
 * was requested). 0 if dev is NULL. */
unsigned int mad_device_sample_rate(void *dev)
{
    if (dev == NULL) {
        return 0;
    }
    return ((mad_device *)dev)->device.sampleRate;
}

/* the channel count the callback is fed (resolved native count when 0 was
 * requested). 0 if dev is NULL. */
unsigned int mad_device_channels(void *dev)
{
    if (dev == NULL) {
        return 0;
    }
    return ((mad_device *)dev)->device.playback.channels;
}
