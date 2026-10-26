#include "car.h"
#include <stdio.h>
#include <stdlib.h>

static unsigned ready(Car *c){
    car_init(c);
    car_poll(c,0xc1000000u,1500,1,0);
    car_poll(c,0xc1000011u,1500,1,20);
    for(unsigned t=40;t<=600;t+=20)car_poll(c,0xc1000011u,1500,1,t);
    if(!c->centered || !c->allowed || c->stage!=CAR_LISTEN)exit(10);
    return 600;
}
int main(int argc,char **argv){
    if(argc!=2)return 2;
    FILE *f=fopen(argv[1],"w");if(!f)return 3;
    fprintf(f,"elapsed_ms,new_observation,reference_run,actual_run,duty_left,duty_right\n");
    Car c;unsigned start=ready(&c);
    for(unsigned t=0;t<10800;t+=20){
        unsigned now=start+t;int observation=(t%900)==0;
        if(observation)car_observe(&c,1,30.f,now-60,now);
        car_poll(&c,0xc1000011u,1500,1,now);
        unsigned expected=(t%900)<CAR_LOSS_MS;
        unsigned run=(car_command(&c,0)>>18)&1u;
        if(run!=expected || (run && (c.target_left!=83 || c.target_right!=45)))return 11;
        fprintf(f,"%u,%d,%u,%u,%d,%d\n",t,observation,expected,run,c.left,c.right);
    }
    if(fclose(f))return 4;
    start=ready(&c);car_observe(&c,1,30.f,start,start);
    car_poll(&c,0xc1000011u,1500,1,start+CAR_LOSS_MS-1);
    if(!c.fresh)return 12;
    car_poll(&c,0xc1000011u,1500,1,start+CAR_LOSS_MS);
    if(c.fresh || c.left || c.right)return 13;
    car_observe(&c,1,30.f,start+CAR_LOSS_MS-500,start+CAR_LOSS_MS);
    if(c.fresh)return 14;
    printf("BOUNDARY_CHECKS_OK loss_ms=%u stale_ms=%u car_state_bytes=%u\n",
           CAR_LOSS_MS,CAR_SAMPLE_MAX_AGE_MS,(unsigned)sizeof(Car));
    return 0;
}
