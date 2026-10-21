#ifndef SERVO_H
#define SERVO_H
#include <stdint.h>
// Confirmed by the user on hardware: both tracking directions are +1.
#define SERVO_PAN_DIR 1
#define SERVO_TILT_DIR 1
#define SERVO_PAN_MIN 500
#define SERVO_TILT_MIN 1350
#define SERVO_MAX 2500
#define SERVO_LOSS_MS 400u
typedef struct {
 int target[2],actual[2],moving[2];
 float filtered[2],candidate[2];
 unsigned enabled,tracking,hold,locked,pending;
 uint32_t last_valid_ms,candidate_ms;
 // Per-axis reversal guard: PWM feedback is commanded pulse, not shaft feedback.
 int direction[2];unsigned reverse_count[2];
 float reverse_error[2];uint32_t reverse_started[2],reverse_last[2];
} Servo;
void servo_init(Servo *s);
void servo_start(Servo *s,uint32_t now);
void servo_off(Servo *s);
void servo_hold(Servo *s);
void servo_feedback(Servo *s,uint32_t status);
void servo_tick(Servo *s,uint32_t now);
void servo_observe(Servo *s,int valid,float az,float el,uint32_t now);
// Only pass valid=1 after acoustic continuity/acquisition validation.
void servo_observe_confirmed(Servo *s,int valid,float az,float el,uint32_t now);
uint32_t servo_control(const Servo *s,unsigned heartbeat,unsigned capture);
#endif
