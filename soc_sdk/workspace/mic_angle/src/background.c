#include "background.h"
#include <math.h>
#include <string.h>
void background_init(Background *b){memset(b,0,sizeof(*b));}
// Calibrate with both powered servos stationary. Upper quartile resists an
// underestimated quiet floor, while ignoring a few startup/transient peaks.
int background_add(Background *b,float rms){
 if(b->ready)return 1;
 if(!isfinite(rms) || rms<0)return 0;
 b->level[b->count++]=rms;
 if(b->count<BACKGROUND_BLOCKS)return 0;
 for(unsigned i=1;i<BACKGROUND_BLOCKS;i++){
  float value=b->level[i];unsigned j=i;
  while(j && b->level[j-1]>value){b->level[j]=b->level[j-1];j--;}
  b->level[j]=value;
 }
 b->noise_rms=fmaxf(1.f,b->level[BACKGROUND_BLOCKS*3/4-1]);b->ready=1;return 1;
}
