#include "car.h"
#include <string.h>
#include <math.h>
static int bound(int v,int lo,int hi){return v<lo?lo:v>hi?hi:v;}
void car_init(Car *c){memset(c,0,sizeof(*c));c->epoch=0xffffffffu;}
void car_stop(Car *c){
 c->fresh=0;c->have_angle=0;c->left=c->right=c->target_left=c->target_right=0;
 c->stage=!c->mode?CAR_DISPLAY:!c->allowed?CAR_BLOCKED:!c->centered?CAR_CENTERING:CAR_LISTEN;
}
int car_poll(Car *c,uint32_t status,int pan_pwm,int allowed,uint32_t now){
 unsigned mode=status&1u,epoch=(status>>4)&15u;
 int changed=c->epoch!=epoch || c->mode!=mode;
 c->pl_status=status;c->mode=mode;c->epoch=epoch;
 c->allowed=allowed && (status>>24)==0xc1u && !(status&2u);
 if(changed || !c->allowed || !mode){
  c->centered=c->centering=0;c->last_ramp_ms=now;car_stop(c);
  return changed;
 }
 if(pan_pwm<CAR_PAN_CENTER_US-10 || pan_pwm>CAR_PAN_CENTER_US+10){
  c->centered=c->centering=0;car_stop(c);return changed;
 }
 if(!c->centered){
  if(!c->centering){c->center_since=now;c->centering=1;}
  if((uint32_t)(now-c->center_since)>=CAR_CENTER_SETTLE_MS)c->centered=1;
  car_stop(c);return changed;
 }
 if(!c->fresh || (uint32_t)(now-c->last_sample_ms)>=CAR_LOSS_MS){car_stop(c);return changed;}
 if((uint32_t)(now-c->last_ramp_ms)>=20u){
  c->last_ramp_ms=now;
  // Renew the bounded audio lease only while a real result is <CAR_LOSS_MS old.
  // PL bit21 watches this lease; bit19 separately watches the CPU heartbeat.
  // Invalid results never extend last_sample_ms. A stalled PS still stops in PL.
  c->source_sequence^=1u;
  // Acceleration 3/256 per 20ms. Decelerate faster; timeout/fault bypass ramp.
  c->left+=bound(c->target_left-c->left,-6,3);
  c->right+=bound(c->target_right-c->right,-6,3);
 }
 return changed;
}
void car_observe(Car *c,int accepted,float az,uint32_t sample_ms,uint32_t now){
 if(!c->mode || !c->allowed || !c->centered){car_stop(c);return;}
 if(!accepted || !isfinite(az) || fabsf(az)>180.f ||
    (uint32_t)(now-sample_ms)>=CAR_SAMPLE_MAX_AGE_MS){
  // Brief speech gaps keep the last forward arc; silence never renews the lease.
  if(!c->fresh || (uint32_t)(now-c->last_sample_ms)>=CAR_LOSS_MS)car_stop(c);
  return;
 }
 // Use the current accepted acoustic bearing, not the delayed screen marker.
 // PWM slew limiting below the target provides acceleration smoothing.
 c->steer=az;c->have_angle=1;
 float a=fabsf(c->steer),turn=0;
 if(a>CAR_DEADBAND_DEG)turn=(a-CAR_DEADBAND_DEG)*CAR_TURN_DUTY/(CAR_FULL_TURN_DEG-CAR_DEADBAND_DEG);
 if(turn>CAR_TURN_DUTY)turn=CAR_TURN_DUTY;
 int delta=(int)lroundf(turn)*(c->steer>=0?1:-1);
 // Positive az = source right: left wheel faster, right wheel slower.
 c->target_left=bound(CAR_BASE_DUTY+delta,0,CAR_MAX_DUTY);
 c->target_right=bound(CAR_BASE_DUTY-delta,0,CAR_MAX_DUTY);
 c->last_sample_ms=now;c->fresh=1;c->stage=CAR_DRIVE;
}
uint32_t car_command(const Car *c,unsigned heartbeat){
 unsigned run=c->mode && c->allowed && c->centered && c->fresh;
 return (run?(unsigned)c->left:0u)|((run?(unsigned)c->right:0u)<<8)
 |(CAR_LEFT_FORWARD<<16)|(CAR_RIGHT_FORWARD<<17)|(run<<18)
 |((heartbeat&1u)<<19)|((c->mode&1u)<<20)|((c->source_sequence&1u)<<21);
}
