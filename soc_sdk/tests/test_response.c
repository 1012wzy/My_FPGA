#include <assert.h>
#include <stdio.h>
#include <math.h>
#include "sound_marker.h"
#include "servo.h"
static void feed(SoundMarker *m,Servo *s,DoaResult r,unsigned t){
 marker_update(m,&r,1000,t);
#ifdef SOS2_BASELINE
 servo_observe(s,m->accepted,r.az,r.el,t);
#else
 servo_observe_confirmed(s,m->accepted,r.az,r.el,t);
#endif
}
static unsigned onset(float rms,float coh,float margin){
 SoundMarker m;Servo s;marker_init(&m);servo_init(&s);servo_start(&s,0);
 DoaResult r={0};r.rms=rms;r.coherence=coh;r.margin=margin;r.tonality=.2f;r.az=15;
 for(unsigned t=120;t<=1200;t+=120){feed(&m,&s,r,t);if(!s.hold&&s.target[0]>1500)return t;}
 return 0;
}
int main(void){
 unsigned strong=onset(1600,.96f,.15f),speech=onset(1300,.82f,.07f);
 SoundMarker m;Servo s;marker_init(&m);servo_init(&s);servo_start(&s,0);
 DoaResult r={0};r.rms=1600;r.coherence=.82f;r.margin=.07f;r.tonality=.2f;r.az=15;
 unsigned voiced=0,dropouts=0,locked_at=0;
 for(unsigned t=120,n=0;t<=3600;t+=120,n++){
  r.rms=n%3==0?1600.f:1180.f;feed(&m,&s,r,t);
  if(m.valid){voiced++;if(!locked_at)locked_at=t;}
  if(locked_at&&(!m.locked||s.hold))dropouts++;
 }
 unsigned motion=0;marker_init(&m);servo_init(&s);servo_start(&s,0);
 r.rms=1600;r.coherence=.96f;r.margin=.15f;r.az=-30;
 feed(&m,&s,r,0);feed(&m,&s,r,120);
 for(unsigned n=1;n<=12;n++){
  r.az=-30.f+5.f*n;feed(&m,&s,r,120+120*n);motion+=m.accepted!=0;
 }
 // One invalid block must not force a new acquire before the next valid block.
 marker_init(&m);servo_init(&s);servo_start(&s,0);r.az=15;
 feed(&m,&s,r,120);feed(&m,&s,r,240);feed(&m,&s,r,360);
 r.rms=1000;feed(&m,&s,r,480);r.rms=1600;feed(&m,&s,r,600);
 unsigned resumed=!s.hold&&s.target[0]>1500;
 // Isolated and paired distant peaks still cannot move a centred mount.
 marker_init(&m);servo_init(&s);servo_start(&s,0);r.az=0;
 feed(&m,&s,r,0);feed(&m,&s,r,120);feed(&m,&s,r,240);
 for(unsigned n=0;n<30;n++){
  r.az=n%3==2?0:22;r.el=n%3==2?0:-15;feed(&m,&s,r,360+120*n);
  assert(s.target[0]==1500&&s.target[1]==1600);
 }
 printf("RESPONSE_METRICS strong_onset_ms=%u moderate_speech_onset_ms=%u voice_visible_blocks=%u/30 voice_acquire_ms=%u voice_dropouts=%u moving_accepted=%u/12 resume_after_one_dip=%u\n",strong,speech,voiced,locked_at,dropouts,motion,resumed);
#ifndef SOS2_BASELINE
 assert(strong==240&&speech==240);
 assert(locked_at&&locked_at<=480&&voiced>=27&&dropouts==0);
 assert(motion==12&&resumed);
 // A weak bridge neither increments confirmation count nor renews its age.
 marker_init(&m);servo_init(&s);servo_start(&s,0);r.az=r.el=0;r.rms=1600;r.coherence=.82f;r.margin=.07f;
 feed(&m,&s,r,0);assert(!m.locked&&m.pending==1);
 r.rms=1180;feed(&m,&s,r,120);feed(&m,&s,r,240);feed(&m,&s,r,360);
 assert(!m.locked&&m.pending==1&&m.candidate_ms==0);
 feed(&m,&s,r,480);assert(!m.locked&&!m.pending&&s.hold);
 // A stale lock cannot bootstrap a new source through continuation.
 marker_init(&m);servo_init(&s);servo_start(&s,0);r.rms=1600;
 feed(&m,&s,r,0);feed(&m,&s,r,120);assert(m.locked);
 r.rms=1180;feed(&m,&s,r,840);feed(&m,&s,r,860);
 assert(!m.locked&&!m.accepted&&s.hold);
 // Merely increasing volume cannot bypass ambiguity, tonal or NaN rejection.
 for(unsigned i=0;i<3;i++){
  marker_init(&m);servo_init(&s);servo_start(&s,0);r.rms=16000;r.coherence=.96f;r.margin=.15f;r.tonality=.2f;
  if(i==0)r.margin=.01f;
  if(i==1)r.tonality=.8f;
  if(i==2)r.coherence=NAN;
  for(unsigned t=0;t<2400;t+=120){feed(&m,&s,r,t);assert(!m.locked&&s.hold);}
 }
 puts("PASS: fast confirmed acquisition, moderate/interrupted voice, moving acoustic continuity, short-dip recovery, weak-bridge expiry, paired-echo rejection, no quality-gate bypass");
#else
 puts("SOS2_BASELINE_MEASURED");
#endif
 return 0;
}
