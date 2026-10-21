#ifndef SOUND_MARKER_CONFIG_H
#define SOUND_MARKER_CONFIG_H
// UNCALIBRATED initial pinhole model: assumed 60 degree horizontal FOV.
// Coordinates refer to the final upright HDMI image, after its 180 degree rotation.
#define MARKER_WIDTH 1280
#define MARKER_HEIGHT 720
#define MARKER_FX 1108.51f
#define MARKER_FY 1108.51f
#define MARKER_CX 639.5f
#define MARKER_CY 359.5f
#define MARKER_AZ_ZERO 0.0f
#define MARKER_EL_ZERO 0.0f
#define MARKER_X_SIGN 1
#define MARKER_Y_SIGN 1
// Shared tracking/display observation gates; original DOA estimator unchanged.
#define MARKER_MIN_RMS 100.f
#define MARKER_NOISE_RATIO 1.4f
// Lower level gate ONLY for spatially unambiguous, highly coherent audio.
#define MARKER_WEAK_NOISE_RATIO 1.15f
#define MARKER_WEAK_COHERENCE .90f
#define MARKER_WEAK_MARGIN .10f
#define MARKER_WEAK_MAX_TONALITY .50f
// Speech with moderate spatial contrast need not meet the strong .90/.10 tier.
#define MARKER_SPEECH_NOISE_RATIO 1.25f
#define MARKER_SPEECH_COHERENCE .80f
#define MARKER_SPEECH_MARGIN .05f
#define MARKER_MIN_COHERENCE .35f
#define MARKER_MIN_MARGIN .015f
#define MARKER_MAX_TONALITY .6f
#define MARKER_LOSS_MS 700u
#define MARKER_CONTINUE_NOISE_RATIO 1.10f
#define MARKER_CONTINUE_MS 750u // weak continuation cannot renew itself forever
#define MARKER_ACQUIRE_GAP_MS 400u // expire unconfirmed candidates; invalid observations clear them immediately
// Pixel correction AFTER projection, in the final 1280x720 image.
// Reset old crop compensation after enabling full-ROI sensor scaling.
// Zero degrees projects to image centre; focal lengths still need calibration.
#ifndef MARKER_OFFSET_X
#define MARKER_OFFSET_X (0.0f)
#endif
#ifndef MARKER_OFFSET_Y
#define MARKER_OFFSET_Y (0.0f)
#endif
// 1 holds the powered mount at startup centers for alignment, 0 normal tracking.
#define MARKER_CALIBRATION_HOLD_SERVOS 0
#endif
