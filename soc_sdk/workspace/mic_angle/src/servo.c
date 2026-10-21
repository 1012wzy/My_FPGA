#include "servo.h"
#include <string.h>
#include <math.h>
static int clamp(int v,int lo,int hi){return v<lo?lo:v>hi?hi:v;}
void servo_init(Servo *s){memset(s,0,sizeof(*s));s->hold=1;s->target[0]=s->actual[0]=1500;s->target[1]=s->actual[1]=1600;}
void servo_start(Servo *s,uint32_t now){s->enabled=3;s->tracking=1;s->hold=1;s->locked=s->pending=0;s->last_valid_ms=now;s->direction[0]=s->direction[1]=0;s->reverse_count[0]=s->reverse_count[1]=0;}
void servo_off(Servo *s){s->enabled=s->tracking=s->locked=s->pending=0;s->hold=1;}
void servo_feedback(Servo *s,uint32_t status){s->actual[0]=(status>>5)&4095;s->actual[1]=(status>>17)&4095;}
uint32_t servo_control(const Servo *s,unsigned h,unsigned c){
 return (c&1u)|((uint32_t)clamp(s->target[0],SERVO_PAN_MIN,SERVO_MAX)<<1)
 |((uint32_t)clamp(s->target[1],SERVO_TILT_MIN,SERVO_MAX)<<13)
 |((s->enabled&3u)<<25)|((h&1u)<<27)|((s->hold&1u)<<28);
}
void servo_tick(Servo *s,uint32_t now){
 if(s->tracking && (s->locked || !s->hold) && (uint32_t)(now-s->last_valid_ms)>=SERVO_LOSS_MS){
  s->hold=1;s->locked=0;s->pending=0;s->moving[0]=s->moving[1]=0;
  s->direction[0]=s->direction[1]=0;s->reverse_count[0]=s->reverse_count[1]=0;
  s->target[0]=s->actual[0];s->target[1]=s->actual[1];
 }
}
static void observe(Servo *s,int valid,float az,float el,uint32_t now,int confirmed){
 if(!s->tracking || s->enabled!=3)return;
 servo_tick(s,now);
 if(!valid || !isfinite(az)||!isfinite(el)||fabsf(az)>75||fabsf(el)>60){
  s->pending=0;return; // isolated noisy candidates cannot accumulate across gaps
 }
 float e[2]={az,el};
 // Two observations acquire a source; three consistent large jumps switch it.
 int jump=s->locked && (fabsf(az-s->filtered[0])>25 || fabsf(el-s->filtered[1])>25);
 if(!s->locked || jump){
  if(s->pending && (uint32_t)(now-s->candidate_ms)>=SERVO_LOSS_MS)s->pending=0;
  s->candidate_ms=now;
  if(!s->pending || fabsf(az-s->candidate[0])>12 || fabsf(el-s->candidate[1])>12)s->pending=1;
  else s->pending++;
  s->candidate[0]=az;s->candidate[1]=el;
  if(!confirmed && s->pending<(jump?3u:2u)){
   // A large unconfirmed jump must not leave the old motion lead active.
   if(jump){s->target[0]=s->actual[0];s->target[1]=s->actual[1];s->moving[0]=s->moving[1]=0;s->hold=1;}
   return;
  }
  s->locked=1;s->pending=0;s->filtered[0]=az;s->filtered[1]=el;
 }else{
  s->pending=0;for(int i=0;i<2;i++)s->filtered[i]+=.60f*(e[i]-s->filtered[i]);
 }
 s->last_valid_ms=now;s->hold=0;
 for(int i=0;i<2;i++){
  float raw=e[i];int raw_dir=raw>0?1:-1;
  // Stop the old lead immediately on a contrary observation; do not instantly
  // reverse the mount on near-field/echo jitter. Require 2 clustered samples
  // spanning at least 80ms. Same-direction pursuit stays continuous.
  if(s->direction[i] && raw_dir!=s->direction[i] && fabsf(raw)>=5.f){
   if(!s->reverse_count[i] || (uint32_t)(now-s->reverse_last[i])>=200u ||
      fabsf(raw-s->reverse_error[i])>6.f){
    s->reverse_count[i]=1;s->reverse_started[i]=now;s->reverse_error[i]=raw;
   }else s->reverse_count[i]++;
   s->reverse_last[i]=now;
   s->target[i]=s->actual[i];s->moving[i]=0;s->filtered[i]=0;
   if(s->reverse_count[i]<2u || (uint32_t)(now-s->reverse_started[i])<80u)continue;
   s->direction[i]=raw_dir;s->filtered[i]=raw;s->reverse_count[i]=0;
  }else s->reverse_count[i]=0;
  float error=s->filtered[i],m=fabsf(error);
  if(m<=3)s->moving[i]=0;else if(m>=5)s->moving[i]=1;
  // Retain coarse response; reduce lead only near the acoustic centre.
  float gain=m<12 ? 5.f : 8.f;
  int desired=error>0?1:-1;
  // Filter lag alone must not bypass reversal confirmation.
  if(s->moving[i] && s->direction[i] && desired!=s->direction[i])s->moving[i]=0;
  if(s->moving[i])s->direction[i]=desired;
  int offset=s->moving[i]?clamp((int)(error*gain),-180,180):0;
  int dir=i==0?SERVO_PAN_DIR:SERVO_TILT_DIR;
  // Bounded lead from actual PWM, not an accumulating position integrator.
  s->target[i]=clamp(s->actual[i]+dir*offset,i==0?SERVO_PAN_MIN:SERVO_TILT_MIN,SERVO_MAX);
 }
}

// Untrusted standalone callers retain acquisition checks. The normal program
// already confirmed a fresh acoustic track, so do not add a second acquisition.
void servo_observe(Servo *s,int valid,float az,float el,uint32_t now){observe(s,valid,az,el,now,0);}
void servo_observe_confirmed(Servo *s,int valid,float az,float el,uint32_t now){observe(s,valid,az,el,now,1);}

// Explicit calibration/fault hold; normal proportional pursuit is unchanged.
void servo_hold(Servo *s){
 s->hold=1;s->locked=s->pending=0;
 for(int i=0;i<2;i++){
  s->target[i]=s->actual[i];s->moving[i]=s->direction[i]=0;
  s->reverse_count[i]=0;s->filtered[i]=0;
 }
}
