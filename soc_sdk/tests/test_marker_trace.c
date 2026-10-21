#include "sound_marker.h"
#include "servo.h"
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
// Replay diagnostic snapshots, not raw audio. No accuracy inference is made.
int main(int argc,char **argv){
 assert(argc==3);FILE *f=fopen(argv[1],"r");assert(f);char line[512];assert(fgets(line,sizeof(line),f));
 SoundMarker m;marker_init(&m);unsigned n=0,accepted=0,visible=0,motions=0,candidates=0,last_block=~0u;
 Servo servo;servo_init(&servo);servo_start(&servo,0);
 while(fgets(line,sizeof(line),f)){
  unsigned ms,block,reason;int rms,threshold,c,margin,tone,az,el;
  int cols=sscanf(line,"%u,%u,%u,%d,%d,%d,%d,%d,%d,%d",&ms,&block,&reason,&rms,&threshold,&c,&margin,&tone,&az,&el);
  assert(cols==10);if(block==last_block)continue;last_block=block;
  DoaResult d={0};d.rms=(float)rms;d.coherence=c/1000.f;d.margin=margin/1000.f;d.tonality=tone/1000.f;d.az=az/1000.f;d.el=el/1000.f;
  unsigned why=marker_update(&m,&d,threshold/1.4f,ms);
  servo_observe(&servo,m.accepted,d.az,d.el,ms);
  candidates+=marker_reject_reason(&d,threshold/1.4f)==0;
  motions+=servo.target[0]!=servo.actual[0] || servo.target[1]!=servo.actual[1];
  n++;accepted+=why==0;visible+=m.valid!=0;
 }
 fclose(f);if(atoi(argv[2]))assert(visible==0 && motions==0);
 printf("PASS: snapshot replay %s rows=%u candidates=%u visible=%u accepted=%u motions=%u (not an acoustic accuracy test)\n",argv[1],n,candidates,visible,accepted,motions);
 return 0;
}
