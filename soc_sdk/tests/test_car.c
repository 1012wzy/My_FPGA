#include <assert.h>
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include "car.h"
static uint32_t now;
static void ready(Car *c){
 car_init(c);now=0;car_poll(c,0xc1000000u,1500,1,now);
 now=20;assert(car_poll(c,0xc1000011u,1500,1,now));
 for(now=40;now<=600;now+=20)car_poll(c,0xc1000011u,1500,1,now);
 assert(c->centered && c->stage==CAR_LISTEN);
}
static void poll(Car *c,unsigned ms){for(unsigned i=0;i<ms;i+=20){now+=20;car_poll(c,0xc1000011u,1500,1,now);}}
int main(void){
 Car c;car_init(&c);assert(!(car_command(&c,0)&(1u<<18)));
 ready(&c);
 // Sweep all physically representable bearings: no az alignment gate, reverse or pivot.
 for(int a=-180;a<=180;a++){
  car_observe(&c,1,(float)a,now-60,now);
  assert(c.fresh && c.target_left>0 && c.target_right>0);
  assert(c.target_left+c.target_right==2*CAR_BASE_DUTY);
  assert(c.target_left<=CAR_MAX_DUTY && c.target_right<=CAR_MAX_DUTY);
  if(abs(a)<=10)assert(c.target_left==64 && c.target_right==64);
  else if(a>0)assert(c.target_left>=c.target_right);
  else assert(c.target_left<=c.target_right);
  if(a>=50)assert(c.target_left==102 && c.target_right==26);
  if(a<=-50)assert(c.target_left==26 && c.target_right==102);
 }
 car_observe(&c,1,30,now,now);assert(c.target_left==83 && c.target_right==45);
 // Turning starts without first approaching az=0; both outputs remain forward.
 poll(&c,100);assert(c.left==15 && c.right==15);
 for(int i=0;i<8;i++){car_observe(&c,1,50,now,now);poll(&c,100);}
 assert(c.left==102 && c.right==26);
 unsigned last=now;car_observe(&c,1,50,now,now);
 for(int i=0;i<59;i++){
  unsigned seq=c.source_sequence;poll(&c,20);assert(c.source_sequence!=seq);
  car_observe(&c,0,50,now,now);assert(c.fresh && c.left>0 && c.right>0);
  assert(c.last_sample_ms==last); // rejected observations cannot extend the timer
 }
 now=last+1199;car_poll(&c,0xc1000011u,1500,1,now);assert(c.fresh);
 now=last+1200;car_poll(&c,0xc1000011u,1500,1,now);
 assert(!c.fresh && !c.left && !c.right && !(car_command(&c,1)&(1u<<18)));
 unsigned stopped_seq=c.source_sequence;poll(&c,100);assert(c.source_sequence==stopped_seq);
 car_observe(&c,1,-70,now,now);poll(&c,20);assert(c.fresh && c.left>0 && c.right>0);
 // Fresh out-of-range/NaN/stale values cannot restart a stopped car.
 car_stop(&c);car_observe(&c,1,0,now-CAR_SAMPLE_MAX_AGE_MS,now);assert(!c.fresh);
 car_observe(&c,1,NAN,now,now);assert(!c.fresh);
 car_observe(&c,1,181,now,now);assert(!c.fresh);
 car_observe(&c,1,10,now,now);assert(c.target_left==64 && c.target_right==64);
 car_poll(&c,0xc1000013u,1500,1,now+20);assert(!c.allowed && !c.left && !c.centered);
 ready(&c);car_observe(&c,1,30,now,now);poll(&c,100);
 car_poll(&c,0xc1000020u,1500,1,now+20);assert(!c.mode && !c.left && c.stage==CAR_DISPLAY);
 ready(&c);car_observe(&c,1,30,now,now);poll(&c,100);
 car_poll(&c,0xc1000011u,1490,0,now+20);assert(!c.left && !c.centered);
 ready(&c);car_observe(&c,1,30,now,now);poll(&c,100);
 car_poll(&c,0xc1000011u,1550,1,now+20);assert(!c.left && !c.centered);
 ready(&c);car_observe(&c,1,30,now,now);poll(&c,100);
 car_poll(&c,0x0011,1500,1,now+20);assert(!c.left && !c.allowed);
 // Unsigned elapsed time is correct across millisecond wrap.
 ready(&c);now=0xfffffff0u;car_observe(&c,1,0,now,now);
 car_poll(&c,0xc1000011u,1500,1,1183);assert(c.fresh);
 car_poll(&c,0xc1000011u,1500,1,1184);assert(!c.fresh);
 // Repeated 900ms gaps must not ramp down and restart between voiced blocks.
 ready(&c);car_observe(&c,1,30,now,now);poll(&c,400);car_observe(&c,1,30,now,now);
 for(unsigned gap=0;gap<12;gap++){
  poll(&c,900);assert(c.fresh && c.left>0 && c.right>0);
  car_observe(&c,1,30,now-60,now);
 }
 car_stop(&c);car_observe(&c,1,30,now-500,now);assert(!c.fresh);
 puts("PASS: repeated 900ms speech gaps remain driven; 500ms stale samples cannot restart");
 puts("PASS: CAR rolling +/-180 bearing sweep, 10deg deadband/50deg saturation, both wheels forward, 1199ms hold/1200ms stop, lease/auto recovery, mode/key/fault/center interlocks and time wrap");
 return 0;
}
