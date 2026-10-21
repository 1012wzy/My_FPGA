#ifndef SERVO_STARTUP_H
#define SERVO_STARTUP_H
#include "servo.h"
// settle services heartbeat/fault handling and returns nonzero on failure.
// commit writes the current control word. No tracking observations during settle.
int servo_startup(Servo *s, int (*settle)(unsigned), void (*commit)(void),
                  uint32_t (*now)(void));
#endif
