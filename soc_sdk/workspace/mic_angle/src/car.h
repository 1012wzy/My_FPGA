#ifndef CAR_H
#define CAR_H
#include <stdint.h>
// Open-loop duty, not measured wheel speed. 256 counts = 100%.
#define CAR_BASE_DUTY 64
#define CAR_TURN_DUTY 38
#define CAR_MAX_DUTY 115
#define CAR_DEADBAND_DEG 10.f
#define CAR_FULL_TURN_DEG 50.f
#define CAR_LOSS_MS 1200u
// Reject stale audio independently of the longer speech-gap grace period.
#define CAR_SAMPLE_MAX_AGE_MS 500u
#define CAR_CENTER_SETTLE_MS 500u
#define CAR_PAN_CENTER_US 1500
#define CAR_LEFT_FORWARD 1u
#define CAR_RIGHT_FORWARD 1u
// Both wheel targets remain strictly forward, including full steering.
#if CAR_BASE_DUTY <= CAR_TURN_DUTY || CAR_BASE_DUTY + CAR_TURN_DUTY > CAR_MAX_DUTY
#error Invalid rolling-steering duty limits
#endif
// Change these two polarity settings only after an unloaded wheel test.
enum {CAR_DISPLAY=0,CAR_CENTERING=1,CAR_LISTEN=2,CAR_DRIVE=3,CAR_BLOCKED=4};
typedef struct {
 unsigned mode,epoch,stage,allowed,centered,centering,fresh,source_sequence,have_angle;
 // last_sample_ms is the time the latest fresh, accepted result was received.
 uint32_t center_since,last_sample_ms,last_ramp_ms,pl_status;
 int left,right,target_left,target_right;
 float steer;
} Car;
void car_init(Car *c);
// Returns 1 on a mode epoch change; caller discards samples crossing that change.
int car_poll(Car *c,uint32_t pl_status,int pan_pwm_us,int allowed,uint32_t now);
void car_observe(Car *c,int accepted,float az,uint32_t sample_ms,uint32_t now);
void car_stop(Car *c);
uint32_t car_command(const Car *c,unsigned heartbeat);
#endif
