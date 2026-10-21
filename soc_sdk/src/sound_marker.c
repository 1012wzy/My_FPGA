#include "sound_marker.h"
#include "sound_marker_config.h"
#include <math.h>
#include <string.h>
#define RAD (3.14159265358979323846f/180.f)
float marker_level_threshold(float noise_rms){
 return fmaxf(MARKER_MIN_RMS,noise_rms*MARKER_NOISE_RATIO);
}
float marker_required_level(const DoaResult *r,float noise_rms){
 int coherent=r->coherence>=MARKER_WEAK_COHERENCE && r->margin>=MARKER_WEAK_MARGIN &&
              r->tonality<MARKER_WEAK_MAX_TONALITY;
 int speech=r->coherence>=MARKER_SPEECH_COHERENCE && r->margin>=MARKER_SPEECH_MARGIN &&
            r->tonality<MARKER_WEAK_MAX_TONALITY;
 float ratio=coherent?MARKER_WEAK_NOISE_RATIO:(speech?MARKER_SPEECH_NOISE_RATIO:MARKER_NOISE_RATIO);
 return fmaxf(MARKER_MIN_RMS,noise_rms*ratio);
}
unsigned marker_reject_reason(const DoaResult *r,float noise_rms){
 if(!isfinite(noise_rms)||noise_rms<0||!isfinite(r->rms)||!isfinite(r->coherence)||
    !isfinite(r->margin)||!isfinite(r->tonality)||!isfinite(r->az)||!isfinite(r->el)||
    fabsf(r->az)>75||fabsf(r->el)>60)return 16u;
 unsigned reason=0;
 if(r->rms<=marker_required_level(r,noise_rms))reason|=1u;
 if(r->coherence<=MARKER_MIN_COHERENCE)reason|=2u;
 if(r->margin<=MARKER_MIN_MARGIN)reason|=4u;
 if(r->tonality>=MARKER_MAX_TONALITY)reason|=8u;
 return reason;
}
void marker_init(SoundMarker *m){memset(m,0,sizeof(*m));}
int marker_project(float az,float el,int *x,int *y){
 if(!isfinite(az)||!isfinite(el)||fabsf(az)>75||fabsf(el)>60)return 0;
 float a=(az-MARKER_AZ_ZERO)*MARKER_X_SIGN*RAD;
 float e=(el-MARKER_EL_ZERO)*MARKER_Y_SIGN*RAD;
 float forward=cosf(e)*cosf(a);
 if(forward<=.01f)return 0;
 float px=MARKER_CX+MARKER_OFFSET_X+MARKER_FX*cosf(e)*sinf(a)/forward;
 float py=MARKER_CY+MARKER_OFFSET_Y-MARKER_FY*sinf(e)/forward;
 // Off-screen sources disappear; never clamp them to a misleading edge location.
 if(!isfinite(px)||!isfinite(py)||px<0||px>MARKER_WIDTH-1||py<0||py>MARKER_HEIGHT-1)return 0;
 *x=(int)lroundf(px);*y=(int)lroundf(py);return 1;
}
static float bound(float v,float lo,float hi){return fminf(hi,fmaxf(lo,v));}
void marker_tick(SoundMarker *m,uint32_t now){
 if(m->locked && (uint32_t)(now-m->last_valid_ms)>=MARKER_LOSS_MS){
  m->valid=m->locked=m->pending=m->accepted=m->relocating=0;
  m->velocity[0]=m->velocity[1]=m->motion[0]=m->motion[1]=0;
 }
 if(m->pending && (uint32_t)(now-m->candidate_ms)>=MARKER_ACQUIRE_GAP_MS)m->pending=0;
}
static int candidate(SoundMarker *m,float az,float el,uint32_t now,unsigned needed){
 if(!m->pending || fabsf(az-m->candidate_az)>6.f || fabsf(el-m->candidate_el)>6.f){
  m->pending=1;
 }else m->pending++;
 m->candidate_az=az;m->candidate_el=el;m->candidate_ms=now;
 return (unsigned)m->pending>=needed;
}
static void observe(SoundMarker *m,int valid,float az,float el,float quality,uint32_t now){
 marker_tick(m,now);m->accepted=0;
 if(!valid||!isfinite(az)||!isfinite(el)||fabsf(az)>75||fabsf(el)>60){
  m->pending=0;m->relocating=0;return; // require consecutive real observations
 }
 if(!m->locked){
  if(!candidate(m,az,el,now,2))return;
  m->az=az;m->el=el;m->velocity[0]=m->velocity[1]=m->motion[0]=m->motion[1]=0;
  m->last_measure[0]=az;m->last_measure[1]=el;
  m->locked=1;m->pending=m->relocating=0;
 }else{
  uint32_t elapsed=now-m->last_valid_ms;
  if(!elapsed)return; // duplicated observation must not advance the filter
  float dt=bound(elapsed*.001f,.02f,.25f);
  if(elapsed>300u)m->velocity[0]=m->velocity[1]=0;
  float z[2]={az,el},p[2]={m->az,m->el},pred[2];
  for(unsigned i=0;i<2;i++){
   // Prediction is internal to measurement updates only. Missing audio holds
   // the last coordinate; it never makes a disappearing source keep moving.
   pred[i]=p[i]+bound(m->velocity[i]*dt,-2.f,2.f);
  }
  // Validate motion against the most recent accepted acoustic measurement,
  // never against the deliberately lagged screen coordinate.
  if(elapsed>400u)m->motion[0]=m->motion[1]=0;
  float residual=0;
  for(unsigned i=0;i<2;i++){
   float predicted=m->last_measure[i]+bound(m->motion[i]*dt,-12.f,12.f);
   residual=fmaxf(residual,fabsf(z[i]-predicted));
  }
  float speed=fmaxf(fabsf(m->motion[0]),fabsf(m->motion[1]));
  float gate=6.f+fminf(6.f,speed*dt*.5f);
  int new_track=0;
  if(residual>gate){
   // Keep three confirmations for an unrelated peak; a moving accepted track
   // does not repeatedly reacquire merely because display smoothing trails it.
   if(!candidate(m,az,el,now,3))return;
   new_track=1;m->relocating=1;
  }
  m->pending=0;
  int relocate=m->relocating;
  for(unsigned i=0;i<2;i++)
   m->motion[i]=new_track?0.f:bound(.5f*m->motion[i]+.5f*bound((z[i]-m->last_measure[i])/dt,-90.f,90.f),-90.f,90.f);
  if(relocate){
   m->candidate_az=az;m->candidate_el=el;
   for(unsigned i=0;i<2;i++){
    // Reacquisition is bounded too; no direct assignment to a distant peak.
    p[i]+=bound(z[i]-p[i],-3.f,3.f);m->velocity[i]=0;
   }
   if(fmaxf(fabsf(az-p[0]),fabsf(el-p[1]))<=2.f)m->relocating=0;
  }else{
   float alpha=dt/(.14f-.06f*quality+dt);
   float beta=bound((.06f+.09f*quality)*dt/.12f,.02f,.25f);
   for(unsigned i=0;i<2;i++){
    float dz=z[i]-m->last_measure[i];
    // Reliable slowing/stopping damps velocity before prediction can overshoot.
    if(fabsf(dz)<.8f || dz*m->velocity[i]<0){
     m->velocity[i]*=.35f;
     pred[i]=p[i]+bound(m->velocity[i]*dt,-2.f,2.f);
    }
    float influence=1.5f+.75f*quality;
    float e=bound(z[i]-pred[i],-influence,influence); // bounded influence of a marginal point
    p[i]=pred[i]+alpha*e;
    m->velocity[i]=bound(m->velocity[i]+beta*e/dt,-45.f,45.f);
   }
  }
  m->az=bound(p[0],-75.f,75.f);m->el=bound(p[1],-60.f,60.f);
  m->last_measure[0]=az;m->last_measure[1]=el;
 }
 m->last_valid_ms=now;m->accepted=1;
 m->valid=marker_project(m->az,m->el,&m->x,&m->y);
}
void marker_observe(SoundMarker *m,int valid,float az,float el,uint32_t now){
 observe(m,valid,az,el,1.f,now);
}
unsigned marker_update(SoundMarker *m,const DoaResult *r,float noise_rms,uint32_t now){
 marker_tick(m,now); // expire stale locks before considering weak continuation
 unsigned strict=marker_reject_reason(r,noise_rms),reason=strict;
 if(reason==1u && m->locked && (uint32_t)(now-m->last_strong_ms)<MARKER_CONTINUE_MS &&
    r->rms>fmaxf(MARKER_MIN_RMS,noise_rms*MARKER_CONTINUE_NOISE_RATIO) &&
    r->coherence>=.75f && r->margin>=.05f &&
    fabsf(r->az-m->last_measure[0])<=12.f && fabsf(r->el-m->last_measure[1])<=12.f)reason=0;
 // A brief quieter voiced block may bridge two strong acquisition samples.
 // It cannot acquire on its own, advance the count or extend its expiry.
 int keep_pending=reason==1u && !m->locked && m->pending &&
    (uint32_t)(now-m->candidate_ms)<MARKER_ACQUIRE_GAP_MS &&
    r->rms>fmaxf(MARKER_MIN_RMS,noise_rms*MARKER_CONTINUE_NOISE_RATIO) &&
    r->coherence>=MARKER_SPEECH_COHERENCE && r->margin>=MARKER_SPEECH_MARGIN &&
    fabsf(r->az-m->candidate_az)<=6.f && fabsf(r->el-m->candidate_el)<=6.f;
 int pending=m->pending;
 float quality=reason?0.f:bound(fminf((r->coherence-.35f)/.55f,(r->margin-.015f)/.10f),0.f,1.f);
 observe(m,reason==0,r->az,r->el,quality,now);
 if(keep_pending)m->pending=pending;
 if(reason==0 && !m->accepted)reason=m->locked?32u:64u;
 if(strict==0 && m->accepted)m->last_strong_ms=now;
 return reason;
}
