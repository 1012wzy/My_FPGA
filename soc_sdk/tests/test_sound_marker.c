#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "sound_marker.h"
#include "sound_marker_config.h"
int main(void){
 int x,y,x2,y2;SoundMarker m;
 int cx=(int)lroundf(MARKER_CX+MARKER_OFFSET_X);
 int cy=(int)lroundf(MARKER_CY+MARKER_OFFSET_Y);
 assert(marker_project(0,0,&x,&y)&&x==cx&&y==cy);
 assert(marker_project(10,0,&x,&y)&&x>cx+190&&y==cy);
 assert(marker_project(-10,0,&x2,&y2)&&abs(x+x2-(int)(2*(MARKER_CX+MARKER_OFFSET_X)))<=1);
 assert(marker_project(0,8,&x,&y)&&y<cy-150);
 assert(marker_project(0,-8,&x2,&y2)&&abs(y+y2-(int)(2*(MARKER_CY+MARKER_OFFSET_Y)))<=1);
 assert(marker_project(20,8,&x2,&y2)&&y2<y); // perspective coupling
 assert(!marker_project(75,0,&x,&y)&&!marker_project(0,60,&x,&y));
 assert(!marker_project(NAN,0,&x,&y)&&!marker_project(0,INFINITY,&x,&y));
 // Shared quality gate may accept weak coherent audio despite legacy DOA valid=0.
 DoaResult r={0};r.rms=1500;r.coherence=.65f;r.margin=.04f;r.tonality=.2f;
 assert(r.valid==0 && marker_reject_reason(&r,1000)==0);
 r.rms=1400;assert(marker_reject_reason(&r,1000)==1); // exact threshold excluded
 r.rms=0;assert(marker_reject_reason(&r,0)==1);
 r.rms=1500;r.tonality=.8f;assert(marker_reject_reason(&r,1000)==8);
 r.tonality=.2f;r.margin=.01f;assert(marker_reject_reason(&r,1000)==4);
 r.margin=.04f;r.coherence=.3f;assert(marker_reject_reason(&r,1000)==2);
 r.coherence=NAN;assert(marker_reject_reason(&r,1000)==16);
 r.coherence=.65f;assert(marker_reject_reason(&r,NAN)==16);
 r.az=INFINITY;assert(marker_reject_reason(&r,1000)==16);
 // Weak audio needs stronger spatial confidence, not a blanket lower threshold.
 r=(DoaResult){0};r.rms=1250;r.coherence=.95f;r.margin=.15f;r.tonality=.2f;
 assert(marker_reject_reason(&r,1000)==0);
 r.coherence=.8f;assert(marker_reject_reason(&r,1000)==1);
 r.coherence=.95f;r.margin=.05f;assert(marker_reject_reason(&r,1000)==1);
 r.margin=.15f;r.rms=1150;assert(marker_reject_reason(&r,1000)==1);


 // Fresh-data acceptance is separate from a held on-screen marker.
 marker_init(&m);marker_observe(&m,1,0,0,0);assert(!m.accepted&&!m.valid);
 marker_observe(&m,1,0,0,120);assert(m.accepted&&m.valid&&m.x==cx&&m.y==cy);
 for(unsigned t=240;t<=360;t+=120){marker_observe(&m,1,20,15,t);assert(!m.accepted&&m.valid&&m.az==0&&m.el==0);}
 marker_observe(&m,1,0,0,480);assert(m.accepted&&m.az==0);
 // True relocation requires three observations, and cannot teleport the spot.
 float prev=m.az;
 for(unsigned t=600;t<=1800;t+=120){
  marker_observe(&m,1,20,0,t);
  assert(fabsf(m.az-prev)<=3.01f);prev=m.az;
 }
 assert(m.valid&&fabsf(m.az-20.f)<1.f);
 marker_tick(&m,2499);assert(m.valid);marker_tick(&m,2500);assert(!m.valid&&!m.locked);
 marker_init(&m);marker_observe(&m,1,0,0,0);marker_observe(&m,1,0,0,401);assert(!m.valid);
 marker_observe(&m,1,0,0,521);assert(m.valid);
 marker_init(&m);marker_observe(&m,1,0,0,0xffffff00u);marker_observe(&m,1,0,0,0xffffff80u);
 marker_tick(&m,0x23bu);assert(m.valid);marker_tick(&m,0x23cu);assert(!m.valid);
 // Alternating background peaks cannot establish a source.
 marker_init(&m);
 for(unsigned t=0;t<2000;t+=120){marker_observe(&m,1,t%240?30.f:-30.f,0,t);assert(!m.locked);}
 // Static noise plus isolated and paired echo spikes.
 marker_init(&m);marker_observe(&m,1,0,0,0);marker_observe(&m,1,0,0,120);
 const float noise[]={-2,1,2,-1,0};
 for(unsigned n=0;n<100;n++){
  float az=(n%17<2)?12.f:noise[n%5];
  marker_observe(&m,1,az,-noise[n%5],240+120*n);
  assert(m.valid&&fabsf(m.az)<2.1f&&fabsf(m.el)<2.1f);
 }
 // Continuous motion and abrupt stop. No median-window delay.
 marker_init(&m);marker_observe(&m,1,-8,0,0);marker_observe(&m,1,-7,0,120);
 float maxlag=0;
 for(unsigned n=0;n<18;n++){
  float az=-6.f+n;marker_observe(&m,1,az,0,240+120*n);
  maxlag=fmaxf(maxlag,fabsf(az-m.az));assert(m.valid&&fabsf(az-m.az)<1.8f);
 }
 for(unsigned n=0;n<3;n++){marker_observe(&m,1,11,0,2400+120*n);assert(m.az<11.8f);}
 assert(fabsf(m.az-11.f)<.6f);
 // No extrapolation during audio gaps, nor duplicate-time velocity changes.
 float last=m.az,vel=m.velocity[0];marker_observe(&m,1,15,0,2640);assert(m.az==last&&m.velocity[0]==vel&&!m.accepted);
 for(unsigned t=2760;t<3300;t+=120){marker_observe(&m,0,0,0,t);assert(m.az==last&&!m.accepted);}
 // Irregular update intervals with a bounded, consistent angular velocity.
 marker_init(&m);marker_observe(&m,1,-10,0,0);marker_observe(&m,1,-9,0,100);
 unsigned time=100;const unsigned intervals[]={80,160,120};
 for(unsigned n=0;n<20;n++){
  time+=intervals[n%3];float truth=-10.f+time*.01f;
  marker_observe(&m,1,truth,0,time);assert(m.accepted&&fabsf(m.az-truth)<2.f);
 }
 // Weak level cannot acquire; bounded continuation cannot sustain silence.
 marker_init(&m);r=(DoaResult){0};r.rms=1200;r.coherence=.8f;r.margin=.08f;r.tonality=.2f;
 for(unsigned t=0;t<1000;t+=120){assert(marker_update(&m,&r,1000,t)==1);assert(!m.valid);}
 r.rms=1600;assert(marker_update(&m,&r,1000,1200)==64);assert(!m.valid);
 assert(marker_update(&m,&r,1000,1320)==0);assert(m.accepted&&m.valid);
 r.rms=1200;assert(marker_update(&m,&r,1000,1440)==0);assert(m.valid);
 r.margin=.01f;assert(marker_update(&m,&r,1000,1560)==5&&!m.accepted);
 r.margin=.08f;assert(marker_update(&m,&r,1000,1680)==0);
 assert(marker_update(&m,&r,1000,1800)==0);
 assert(marker_update(&m,&r,1000,2040)==0);
 assert(marker_update(&m,&r,1000,2080)==1);
 marker_tick(&m,2740);assert(!m.valid);
 // High-quality echo rejected by trajectory must not authorize the servo.
 marker_init(&m);r.rms=1600;r.az=0;r.el=0;
 marker_update(&m,&r,1000,0);marker_update(&m,&r,1000,120);
 r.az=25;assert(marker_update(&m,&r,1000,240)==32&&!m.accepted&&m.valid);
 assert(marker_update(&m,&r,1000,360)==32&&!m.accepted);
 r.az=0;assert(marker_update(&m,&r,1000,480)==0);
 printf("PASS: alpha-beta common track, paired-outlier rejection, bounded relocation, no stale motion, quality/continuation, irregular timing, projection and wrap; motion lag %.3fdeg, stop settling <0.6deg in three updates\n",maxlag);
 return 0;
}
