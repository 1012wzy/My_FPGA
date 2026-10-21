#include "servo_startup.h"
int servo_startup(Servo *s, int (*settle)(unsigned), void (*commit)(void),
                  uint32_t (*now)(void)){
 s->tracking=0;s->hold=1;s->enabled=1;commit();
 if(settle(300))goto failed;
 s->enabled=3;commit();
 if(settle(600))goto failed;
 servo_start(s,now());commit();
 return 0;
failed:
 servo_off(s);commit();return -1;
}
