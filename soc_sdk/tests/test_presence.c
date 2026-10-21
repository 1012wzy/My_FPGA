#include <assert.h>
#include <math.h>
#include <stdio.h>
#include "background.h"
#include "sound_marker.h"
#include "servo.h"
static unsigned feed(SoundMarker *m,Servo *s,DoaResult *r,float noise,unsigned t){
 unsigned reason=marker_update(m,r,noise,t);
 servo_observe_confirmed(s,m->accepted,r->az,r->el,t);
 return reason;
}
int main(void){
 Background b;background_init(&b);
 assert(!background_add(&b,NAN)&&!background_add(&b,INFINITY)&&!background_add(&b,-1)&&b.count==0);
 for(unsigned i=0;i<24;i++)assert(background_add(&b,i<2?9000.f:980.f+(i%5)*10.f)==(i==23));
 assert(b.ready&&b.noise_rms>=1000&&b.noise_rms<=1020);
 float floor=b.noise_rms;assert(background_add(&b,50000)&&b.noise_rms==floor);
 background_init(&b);for(unsigned i=0;i<24;i++)background_add(&b,0);assert(b.noise_rms==1);
 SoundMarker m;Servo s;marker_init(&m);servo_init(&s);servo_start(&s,0);
 DoaResult r={0};r.coherence=.96f;r.margin=.15f;r.tonality=.2f;r.az=25;r.el=-15;
 // Powered stationary background, even when strongly coherent on right/down.
 for(unsigned i=0;i<100;i++){
  r.rms=floor*(1.f+.035f*(i%5));
  assert(feed(&m,&s,&r,floor,i*120)==1);
  assert(!m.locked&&!m.accepted&&s.hold&&s.target[0]==1500&&s.target[1]==1600);
 }
 // Sparse high-level noise spikes must not accumulate into an acquisition.
 for(unsigned i=0;i<100;i++){
  r.rms=floor*(i%2?1.f:2.f);feed(&m,&s,&r,floor,12000+i*120);
  assert(!m.locked&&s.hold&&s.target[0]==1500&&s.target[1]==1600);
 }
 // Moderate coherent source still acquires; P gain/lead have not been slowed.
 r.rms=floor*1.25f;r.az=15;r.el=0;
 for(unsigned i=0;i<3;i++)feed(&m,&s,&r,floor,24000+i*120);
 assert(m.valid&&m.accepted&&!s.hold&&s.target[0]==1620&&s.target[1]==1600);
 unsigned last=24240;
 // Short speech dip holds only the display; loss expires actuator command first.
 r.rms=floor;
 feed(&m,&s,&r,floor,last+120);assert(m.valid&&!m.accepted);
 feed(&m,&s,&r,floor,last+240);assert(m.valid&&!s.hold);
 feed(&m,&s,&r,floor,last+400);assert(m.valid&&s.hold&&s.target[0]==s.actual[0]);
 marker_tick(&m,last+700);assert(!m.locked&&!m.valid);
 // Regression: raw high-quality echoes bypassed the trajectory gate in SOS1.
 marker_init(&m);servo_init(&s);servo_start(&s,0);r.rms=floor*2;r.az=r.el=0;
 for(unsigned i=0;i<3;i++)feed(&m,&s,&r,floor,i*120);
 assert(m.valid&&!s.hold&&s.target[0]==1500&&s.target[1]==1600);
 for(unsigned i=3;i<90;i++){
  r.az=i%3==2?0:20;r.el=i%3==2?0:-12;
  unsigned reason=feed(&m,&s,&r,floor,i*120);
  if(i%3!=2)assert(reason==32&&!m.accepted);
  assert(s.target[0]==1500&&s.target[1]==1600);
 }
 // Moving source plus isolated reflection peaks: measure the synthetic error.
 marker_init(&m);marker_observe(&m,1,-10,0,0);marker_observe(&m,1,-9.5f,0,120);
 float max_error=0,max_step=0,prev=m.az;
 for(unsigned i=0;i<40;i++){
  float truth=-9.f+.5f*i;
  float measured=truth+((i%13==7)?15.f:(i%4==0?.8f:(i%4==2?-.8f:0.f)));
  marker_observe(&m,1,measured,0,240+120*i);
  max_error=fmaxf(max_error,fabsf(m.az-truth));max_step=fmaxf(max_step,fabsf(m.az-prev));prev=m.az;
  assert(m.valid&&fabsf(m.az-truth)<2.5f&&fabsf(m.el)<.01f);
 }
 for(unsigned i=0;i<5;i++)marker_observe(&m,1,10.5f,0,5040+120*i);
 assert(fabsf(m.az-10.5f)<.6f);
 // Whole marker-to-servo path with a bounded-speed, lagged plant model.
 // This checks responsiveness of software gates, not real servo accuracy.
 float pursuit_error=0;
 for(unsigned trial=0;trial<2;trial++){
  marker_init(&m);servo_init(&s);servo_start(&s,0);int pwm=1500;float shaft=1500;
  for(unsigned t=20;t<=6000;t+=20){
   float world=trial?20.f:(t<2000?15.f*t/1000.f:30.f);
   servo_feedback(&s,((unsigned)pwm<<5)|(1600u<<17));servo_tick(&s,t);marker_tick(&m,t);
   if(t%120==0){r.az=world-(shaft-1500.f)/7.4f;r.el=0;r.rms=floor*2;feed(&m,&s,&r,floor,t);}
   int diff=s.target[0]-pwm;if(!s.hold)pwm+=diff>12?12:(diff< -12?-12:diff);
   shaft+=.25f*(pwm-shaft);
   float error=fabsf(world-(shaft-1500.f)/7.4f);
   if(!trial&&t>=1000&&t<=2000){pursuit_error=fmaxf(pursuit_error,error);assert(error<10.f);}
   if(t>=3500)assert(error<5.f);
  }
 }
 printf("PASS: coupled motion/step plant model, 15deg/s pursuit max error %.3fdeg\n",pursuit_error);
 printf("PASS: powered-background percentile, invalid calibration data, right/down quiet rejection, separated spikes, weak source acquisition, unchanged P gain, trajectory-authorized servo, loss hold; noisy-motion max error %.3fdeg max step %.3fdeg\n",max_error,max_step);
 return 0;
}
