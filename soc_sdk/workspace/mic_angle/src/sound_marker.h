#ifndef SOUND_MARKER_H
#define SOUND_MARKER_H
#include <stdint.h>
#include "doa.h"
typedef struct {
 int x,y,valid,locked,pending,accepted,relocating;
 float az,el,velocity[2],last_measure[2],motion[2];
 float candidate_az,candidate_el;
 uint32_t last_valid_ms,candidate_ms,last_strong_ms;
} SoundMarker;
// 1=level,2=coherence,4=margin,8=tone,16=invalid,32=innovation,64=acquiring.
// Quality-only helper; never use it alone to authorize servo motion.
unsigned marker_reject_reason(const DoaResult *r,float noise_rms);
float marker_level_threshold(float noise_rms);
float marker_required_level(const DoaResult *r,float noise_rms);
// Zero means a NEW, trajectory-accepted sample; valid may also hold an old image.
unsigned marker_update(SoundMarker *m,const DoaResult *r,float noise_rms,uint32_t now);
void marker_init(SoundMarker *m);
int marker_project(float az,float el,int *x,int *y);
void marker_tick(SoundMarker *m,uint32_t now);
void marker_observe(SoundMarker *m,int valid,float az,float el,uint32_t now);
#endif
