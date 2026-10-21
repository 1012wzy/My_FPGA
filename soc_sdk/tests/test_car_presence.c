#include <assert.h>
#include <stdio.h>
#include "car.h"
#include "sound_marker.h"
int main(void){
 Car c;SoundMarker m;car_init(&c);marker_init(&m);
 for(unsigned t=0;t<=600;t+=20)car_poll(&c,0xc1000011u,1500,1,t);
 assert(c.centered);
 DoaResult r={0};r.az=12;r.el=0;r.rms=200;r.coherence=.9f;r.margin=.1f;r.tonality=.1f;
 for(unsigned t=720;t<=1200;t+=120){
  marker_update(&m,&r,100,t);car_observe(&c,m.accepted,r.az,t-60,t);
  car_poll(&c,0xc1000011u,1500,1,t+20);
 }
 assert(m.accepted && m.valid && c.fresh && c.left>0);
 // Held on-screen marker never renews a motor lease after silence.
 r.rms=20;marker_update(&m,&r,100,1320);assert(m.valid && !m.accepted);
 car_observe(&c,m.accepted,r.az,1260,1320);assert(c.fresh && c.left>0);
 for(unsigned t=1340;t<=2400;t+=20)car_poll(&c,0xc1000011u,1500,1,t);
 assert(!c.fresh && !c.left && !c.right);
 marker_init(&m);
 for(unsigned t=2500;t<8000;t+=120){
  r.rms=90;r.az=50;r.el=-25;marker_update(&m,&r,100,t);
  car_observe(&c,m.accepted,r.az,t-60,t);car_poll(&c,0xc1000011u,1500,1,t);
  assert(!c.fresh && !c.left && !c.right);
 }
 puts("PASS: acoustic-to-car integration: accepted source drives, held SOS cannot extend 1200ms timeout, quiet right/down background cannot drive");
 return 0;
}
