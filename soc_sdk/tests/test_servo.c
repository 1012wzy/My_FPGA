#include "servo.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
static void fb(Servo *s,int p,int t){servo_feedback(s,((uint32_t)p<<5)|((uint32_t)t<<17));}
static int ab(int n){return n<0?-n:n;}
// Independent bounded-speed plant model. Not a hardware specification.
static int step(int actual,int target,int hold){if(hold)return actual;int d=target-actual;return actual+(d>12?12:d< -12?-12:d);}
int main(void){
 Servo s;servo_init(&s);assert(!s.enabled && s.hold);assert(s.target[0]==1500 && s.target[1]==1600 && s.actual[1]==1600);servo_start(&s,0);assert(s.enabled==3&&s.tracking&&s.hold);
 s.target[0]=500;s.target[1]=2500;uint32_t c=servo_control(&s,1,1);
 assert((c&1)==1 && ((c>>1)&4095)==500 && ((c>>13)&4095)==2500 && ((c>>25)&3)==3 && ((c>>27)&1)==1);
 s.target[0]=9000;s.target[1]=0;c=servo_control(&s,0,0);assert(((c>>1)&4095)==2500&&((c>>13)&4095)==1350);
 fb(&s,2500,1350);assert(s.actual[0]==2500&&s.actual[1]==1350);
 servo_init(&s);servo_start(&s,0);
 // First sound may occur long after boot; must still acquire without UART.
 servo_observe(&s,1,30,10,5000);assert(s.hold);servo_tick(&s,5020);
 servo_observe(&s,1,30,10,5080);assert(!s.hold&&s.locked&&s.target[0]==1680);
 servo_observe(&s,1,-50,0,5160);assert(s.target[0]==s.actual[0]&&s.hold);
 servo_observe(&s,0,0,0,5200);assert(s.hold);servo_tick(&s,5500);assert(s.hold&&!s.locked&&s.target[0]==s.actual[0]);
 servo_observe(&s,1,20,10,6000);servo_observe(&s,1,20,10,6080);assert(!s.hold);
 servo_off(&s);servo_observe(&s,1,20,10,6200);assert(!s.enabled&&!s.tracking);
 servo_init(&s);servo_start(&s,0xfffffff0u);servo_observe(&s,1,20,0,0);servo_observe(&s,1,20,0,80);servo_tick(&s,480);assert(s.hold);
 for(int az=-60;az<=60;az+=20)for(int el=-15;el<=45;el+=15){
  servo_init(&s);servo_start(&s,0);int p=1500,t=1600;
  for(unsigned now=20;now<=18000;now+=20){
   fb(&s,p,t);servo_tick(&s,now);
   if(now%80==0)servo_observe(&s,1,az-(p-1500)/7.4f,el-(t-1600)/7.4f,now);
   int np=step(p,s.target[0],s.hold),nt=step(t,s.target[1],s.hold);
   assert(ab(np-p)<=12&&ab(nt-t)<=12);p=np;t=nt;
   assert(p>=500&&p<=2500&&t>=1350&&t<=2500);
   assert(ab(s.target[0]-s.actual[0])<=180&&ab(s.target[1]-s.actual[1])<=180);
  }
  assert(fabsf(az-(p-1500)/7.4f)<5.5f&&fabsf(el-(t-1600)/7.4f)<5.5f);
 }
 servo_init(&s);servo_start(&s,0);fb(&s,500,1350);
 servo_observe(&s,1,-40,-40,100);servo_observe(&s,1,-40,-40,180);assert(s.target[0]==500&&s.target[1]==1350);
 for(int i=0;i<100;i++){servo_observe(&s,1,NAN,0,200+i*20);}
 assert(s.hold);
 // A fixed source with +/-6 degree near-centre noise must not move the mount.
 servo_init(&s);servo_start(&s,0);servo_observe(&s,1,0,0,20);servo_observe(&s,1,0,0,100);
 for(unsigned now=180;now<3000;now+=80){
  float a=(now/80)%2?6.f:-6.f;servo_observe(&s,1,a,-a,now);
  assert(s.target[0]==1500&&s.target[1]==1600);
 }
 // After established rightward pursuit, isolated leftward errors must stop
 // the lead but never command an immediate leftward move.
 servo_init(&s);servo_start(&s,0);
 servo_observe(&s,1,12,0,20);servo_observe(&s,1,12,0,100);
 assert(s.target[0]>1500);
 for(unsigned now=180;now<2180;now+=80){
  float error=(now/80)%2?-10.f:10.f;servo_observe(&s,1,error,0,now);
  assert(s.target[0]>=1500);
 }
 // A real stable reversal still becomes actionable after confirmation.
 for(unsigned now=2300;now<=2620;now+=80)servo_observe(&s,1,-10,0,now);
 assert(s.target[0]<1500);
 // Reversal timestamps work across 32-bit millis wrap.
 servo_init(&s);servo_start(&s,0xffffff00u);
 servo_observe(&s,1,12,0,0xffffff10u);servo_observe(&s,1,12,0,0xffffff60u);
 servo_observe(&s,1,-10,0,0xffffffb0u);assert(s.target[0]==1500);
 servo_observe(&s,1,-10,0,0xffffffffu);assert(s.target[0]==1500);
 servo_observe(&s,1,-10,0,0x0u);assert(s.target[0]<1500);
 // Moving source + a simple lagged plant: track 15 deg/s, then settle.
 servo_init(&s);servo_start(&s,0);float shaft=1500.f;int pwm=1500;
 for(unsigned now=20;now<=6000;now+=20){
  float world=now<2000?15.f*now/1000.f:30.f;
  fb(&s,pwm,1600);servo_tick(&s,now);
  if(now%120==0)servo_observe(&s,1,world-(shaft-1500.f)/7.4f,0,now);
  pwm=step(pwm,s.target[0],s.hold);shaft+=.25f*(pwm-shaft);
  if(now>=1000 && now<=2000)assert(fabsf(world-(shaft-1500.f)/7.4f)<10.f);
  if(now>=3500)assert(fabsf(world-(shaft-1500.f)/7.4f)<5.f);
 }
 puts("PASS: 12-bit control/status, asymmetric limits, auto-start, delayed acquisition, jitter rejection, confirmed reversal, loss/reacquisition, fault-off, clock wrap and 35 closed-loop scenarios");
 return 0;
}
