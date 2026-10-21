#include <assert.h>
#include <stdio.h>
#include "servo_startup.h"
static Servo s;static unsigned elapsed,phase,fail_phase,commits;
static uint32_t now(void){return elapsed;}
static void commit(void){commits++;}
static int settle(unsigned duration){
 phase++;
 assert(s.hold==1 && s.tracking==0);
 assert(s.enabled==(phase==1?1u:3u));
 assert(duration==(phase==1?300u:600u));
 for(unsigned ms=0;ms<duration;ms+=20){
  elapsed+=20;servo_tick(&s,elapsed);servo_observe(&s,1,40,20,elapsed);
  assert(s.target[0]==1500 && s.target[1]==1600 && !s.locked);
 }
 if(fail_phase==phase){servo_off(&s);return -1;}
 return 0;
}
int main(void){
 for(fail_phase=0;fail_phase<=2;fail_phase++){
  elapsed=phase=commits=0;servo_init(&s);
  int rc=servo_startup(&s,settle,commit,now);
  if(fail_phase){assert(rc==-1 && s.enabled==0 && !s.tracking && s.hold);assert(phase==fail_phase);}
  else{assert(rc==0 && elapsed==900 && s.enabled==3 && s.tracking && s.hold);
   assert(s.last_valid_ms==900 && !s.locked && commits==3);}
 }
 puts("PASS: staggered startup 300+600ms, centers 1500/1600, observations ignored while settling, faults abort both stages");
 return 0;
}
