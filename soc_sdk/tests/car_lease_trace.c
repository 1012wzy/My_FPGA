#include <stdio.h>
#include <stdint.h>
#include "car.h"
// Real PS commands replayed by the unchanged PL motor controller.
int main(int argc,char **argv){
 if(argc!=2)return 1;
 FILE *f=fopen(argv[1],"w");if(!f)return 2;
 Car c;car_init(&c);
 for(uint32_t t=0;t<=2800;t+=20){
  car_poll(&c,0xc1000011u,1500,1,t);
  if((t>=620 && t<=1200 && (t-620)%20==0)||t==2600)
   car_observe(&c,1,50,t-60,t);
  else car_observe(&c,0,50,t,t);
  fprintf(f,"%08x\n",car_command(&c,(t/20)&1));
 }
 return fclose(f)!=0;
}
