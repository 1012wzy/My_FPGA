
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "camera.h"
#include "xgpio.h"
static unsigned word,rises,active,bytes,shift,address,regaddr,writes,fail_nack,wrong_id,clock_ok=1;
static unsigned written[300],elapsed,marker_ack,corrupt_read,status_extra;
static unsigned regvalue(unsigned reg){for(unsigned i=writes;i>0;i--)if((written[i-1]>>8)==reg)return written[i-1]&255;return 0;}
static XGpio_Config config;static XGpio *direction_port;static unsigned direction_word;
XGpio_Config *XGpio_LookupConfig(unsigned base){assert(base==0x41210000 || base==0x41220000);return &config;}
int XGpio_CfgInitialize(XGpio *p,XGpio_Config *c,unsigned a){if(a==0x41220000)direction_port=p;return 0;}
void XGpio_SetDataDirection(XGpio *p,unsigned c,unsigned v){}
void usleep(unsigned usec){elapsed+=usec;}
void XGpio_DiscreteWrite(XGpio *p,unsigned channel,unsigned next){
 if(p==direction_port){assert(channel==1);direction_word=next;return;}
 unsigned old_scl=!(word&1),new_scl=!(next&1),old_sda=!(word&2),new_sda=!(next&2);
 if(old_scl && new_scl && old_sda && !new_sda){active=1;rises=bytes=shift=0;address=0;}
 else if(old_scl && new_scl && !old_sda && new_sda)active=0;
 else if(active && !old_scl && new_scl){
  rises++;
  if(address!=0x79 && rises%9!=0){
   shift=(shift<<1)|new_sda;
   if(rises%9==8){
    if(bytes==0)address=shift;
    else if(bytes==1)regaddr=shift<<8;
    else if(bytes==2)regaddr|=shift;
    else if(bytes==3){assert(writes<300);written[writes++]=(regaddr<<8)|shift;}
    bytes++;shift=0;
   }
  }
 }
 word=next;
}
unsigned XGpio_DiscreteRead(XGpio *p,unsigned channel){
 unsigned sda=!(word&2),scl=!(word&1);
 if(active && scl){
  if(rises>=9 && rises%9==0)sda=fail_nack?1:0;
  else if(address==0x79 && rises>=10 && rises<=17){
   unsigned value=regaddr==0x300a?(wrong_id?0x12:0x56):regaddr==0x300b?0x40:regvalue(regaddr);
   if(corrupt_read && regaddr==0x3a09)value^=1;
   sda=(value>>(17-rises))&1;
  }
 }
 return status_extra|(marker_ack?128:0)|(clock_ok?12:0)|(sda<<1)|scl;
}
static void reset(void){word=rises=active=bytes=shift=address=regaddr=writes=elapsed=fail_nack=wrong_id=0;clock_ok=1;marker_ack=corrupt_read=status_extra=0;memset((void *)&g_camera,0,sizeof(g_camera));}
int main(void){
 reset();assert(camera_init()==0);assert(g_camera.sensor_id==0x5640);assert(writes==261);assert(word&4);assert(elapsed>=60000);
 assert(written[223]==0x380803 && written[224]==0x380920 && written[225]==0x380a01 && written[226]==0x380bc2);
 // Exposure must fit VTS; band lengths derive from unchanged21MHz SCLK.
 unsigned vts=(regvalue(0x380e)<<8)|regvalue(0x380f),hts=(regvalue(0x380c)<<8)|regvalue(0x380d);
 unsigned b50=(regvalue(0x3a08)<<8)|regvalue(0x3a09),b60=(regvalue(0x3a0a)<<8)|regvalue(0x3a0b);
 assert(vts==740 && hts==1892 && b50==21000000u/hts/100u && b60==21000000u/hts/120u);
 assert(((regvalue(0x3a02)<<8)|regvalue(0x3a03))==vts-4);
 assert(((regvalue(0x3a14)<<8)|regvalue(0x3a15))==vts-4);
 assert(regvalue(0x3a0d)==(vts-4)/b60 && regvalue(0x3a0e)==(vts-4)/b50);
 assert((regvalue(0x3a00)&0x24)==0x20 && (regvalue(0x3c01)&0x80) && (regvalue(0x3c00)&4));
 assert(regvalue(0x3035)==0x41 && regvalue(0x3036)==0x69 && regvalue(0x5001)==0xa3 && regvalue(0x3503)==0);
 unsigned saved_bus=word;
 camera_set_direction(1,-75,60);
 assert((direction_word>>29)==6 && ((direction_word>>21)&255)==181 && ((direction_word>>13)&255)==60 && word==saved_bus);
 camera_set_direction(1,20,-15);
 assert((direction_word>>29)==2 && ((direction_word>>21)&255)==20 && ((direction_word>>13)&255)==241 && word==saved_bus);
 camera_set_direction(1,76,0);assert((direction_word>>29)==4);
 camera_set_direction(0,0,0);assert((direction_word>>29)==0);
 assert(g_camera.version==0x43415231u);
 camera_set_marker(1,1279,719);camera_poll();
 assert((word&7)==4 && (word&0x80000000u) && ((word>>19)&2047)==1279 && ((word>>9)&1023)==719);
 unsigned in_flight=word;
 camera_set_marker(1,400,300);camera_poll();assert(word==in_flight);
 marker_ack=1;camera_poll();assert(word==(in_flight&~0x80000000u));
 camera_poll();assert(word==(in_flight&~0x80000000u));
 marker_ack=0;camera_poll();assert((word&0x80000000u)&&((word>>19)&2047)==400);
 marker_ack=1;camera_poll();marker_ack=0;
 camera_set_marker(0,0,0);camera_poll();assert(!(word&0x40000000u)&&(word&4));
 // Exact hardware-counter accumulation including wrap (no toggle alias).
 status_extra=(63u<<11)|(62u<<17)|(61u<<23);camera_poll();
 assert(g_camera.displayed_frames==63 && g_camera.input_frames==62 && g_camera.complete_frames==61);
 status_extra=(2u<<11)|(3u<<17)|(1u<<23);camera_poll();
 assert(g_camera.displayed_frames==66 && g_camera.input_frames==67 && g_camera.complete_frames==65);
 camera_maintain(0);camera_maintain(2999);assert(g_camera.restarts==0);
 camera_maintain(3000);assert(g_camera.restarts==1 && g_camera.recovery_stage==1 && regvalue(0x3008)==0x42);
 unsigned recovery_writes=writes;camera_maintain(3019);assert(writes==recovery_writes);
 camera_maintain(3020);assert(g_camera.recovery_stage==0 && regvalue(0x3008)==2 && (word&4));
 status_extra=(3u<<11)|(4u<<17)|(2u<<23);camera_poll();camera_maintain(5900);
 camera_maintain(6000);assert(g_camera.restarts==1); // fresh frame cancels timeout
 camera_maintain(7401);assert(g_camera.restarts==2);camera_maintain(7421);
 reset();assert(camera_init()==0);camera_maintain(0xffffff00u);camera_maintain(0xac0u);
 assert(g_camera.restarts==1);camera_maintain(0xad4u);assert(g_camera.recovery_stage==0);
 reset();corrupt_read=1;assert(camera_init()==-6 && g_camera.last_register==0x3a09 && !(word&4));
 reset();fail_nack=1;assert(camera_init()==-3);assert(!(word&4));
 reset();wrong_id=1;assert(camera_init()==-4);assert(writes==0 && !(word&4));
 reset();clock_ok=0;assert(camera_init()==-2);assert(!(word&4));
 puts("PASS: CAR1 independent signed direction packets/sequence/validity, SCCB normal ID, 261 register writes, exact-counter wrap, nonblocking recovery, 50Hz banding, bounded exposure, static register readback, 800x450 capture dimensions, ISP scaling enabled, NACK, wrong ID, clock timeout; capture disabled on failure");
 return 0;
}
