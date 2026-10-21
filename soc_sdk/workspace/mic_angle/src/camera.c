#include "camera.h"
#include "camera_regs.h"
#include "xgpio.h"
#include "sleep.h"
#define CAMERA_GPIO_BASE 0x41210000U
#define DIRECTION_GPIO_BASE 0x41220000U
static XGpio direction_gpio;
static unsigned direction_ready,direction_seq;
static XGpio camera_gpio;
static unsigned output_word,initialized,last_frame,last_input,last_complete,marker_word,marker_dirty;
volatile struct CameraTelemetry g_camera;
static unsigned monitor_started;static uint32_t progress_ms,recovery_ms,last_progress_count;
static void write_bus(void){XGpio_DiscreteWrite(&camera_gpio,1,output_word);}
static unsigned read_bus(void){return XGpio_DiscreteRead(&camera_gpio,2);}
static void data_line(unsigned release){
 if(release)output_word&=~2u;else output_word|=2u;
 write_bus();usleep(5);
}
static int clock_line(unsigned release){
 if(release)output_word&=~1u;else output_word|=1u;
 write_bus();usleep(5);
 if(release){for(unsigned i=0;i<100;i++){if(read_bus()&1)return 0;usleep(5);}return -1;}
 return 0;
}
static int bus_start(void){data_line(1);if(clock_line(1))return -1;data_line(0);return clock_line(0);}
static void bus_stop(void){data_line(0);clock_line(1);data_line(1);}
static int send_byte(unsigned value){
 for(int i=7;i>=0;i--){data_line((value>>i)&1);if(clock_line(1))return -1;clock_line(0);}
 data_line(1);if(clock_line(1))return -1;
 int failed=(read_bus()&2)!=0;clock_line(0);return failed?-1:0;
}
static int receive_byte(unsigned *value){
 *value=0;data_line(1);
 for(unsigned i=0;i<8;i++){if(clock_line(1))return -1;*value=(*value<<1)|((read_bus()>>1)&1);clock_line(0);}
 data_line(1);if(clock_line(1))return -1;clock_line(0);return 0;
}
static int sensor_write(unsigned reg,unsigned value){
 int bad=bus_start()||send_byte(0x78)||send_byte(reg>>8)||send_byte(reg&255)||send_byte(value);
 bus_stop();return bad?-1:0;
}
static int sensor_read(unsigned reg,unsigned *value){
 int bad=bus_start()||send_byte(0x78)||send_byte(reg>>8)||send_byte(reg&255);bus_stop();
 if(!bad)bad=bus_start()||send_byte(0x79)||receive_byte(value);
 bus_stop();return bad?-1:0;
}
void camera_set_marker(unsigned valid,unsigned x,unsigned y){
 valid=valid && x<1280 && y<720;
 marker_word=(valid?0x40000000u:0)|((x&2047u)<<19)|((y&1023u)<<9);
 marker_dirty=1;
 g_camera.marker_valid=valid;g_camera.marker_x=x;g_camera.marker_y=y;
}
// Dedicated GPIO: cannot interfere with SCCB or the coordinate handshake.
void camera_set_direction(unsigned valid,int az,int el){
 if(!direction_ready)return;
 valid=valid && az>=-75 && az<=75 && el>=-60 && el<=60;
 direction_seq^=0x80000000u;
 unsigned packet=direction_seq|(valid?0x40000000u:0)
  |(((unsigned)az&255u)<<21)|(((unsigned)el&255u)<<13);
 XGpio_DiscreteWrite(&direction_gpio,1,packet);
}
void camera_poll(void){
 if(!initialized)return;
 unsigned status=read_bus();
 unsigned displayed=(status>>11)&63,input=(status>>17)&63,complete=(status>>23)&63;
 g_camera.status=status;
 // Four-phase XPM handshake: hold the complete coordinate word until acknowledged.
 // SCCB/capture bits 0..2 are preserved on every overlay write.
 if(g_camera.result==0){
  if(output_word&0x80000000u){
   if(status&128u){output_word&=~0x80000000u;write_bus();}
  }else if(!(status&128u) && marker_dirty){
   output_word=(output_word&7u)|marker_word|0x80000000u;marker_dirty=0;write_bus();
  }
 }
 g_camera.displayed_frames+=(displayed-last_frame)&63;
 g_camera.input_frames+=(input-last_input)&63;
 g_camera.complete_frames+=(complete-last_complete)&63;
 last_frame=displayed;last_input=input;last_complete=complete;
 // Six-bit counters cross with Gray encoding. Poll frequently (< one wrap).
}
// One short SCCB transaction per service call; never re-run the long init in
// the tracking loop. Stream standby/restart keeps PL bank ownership intact.
void camera_maintain(uint32_t now){
 if(!initialized || g_camera.result!=0)return;
 if(!monitor_started){monitor_started=1;progress_ms=recovery_ms=now;last_progress_count=g_camera.displayed_frames;return;}
 if(g_camera.displayed_frames!=last_progress_count){last_progress_count=g_camera.displayed_frames;progress_ms=now;}
 if(g_camera.recovery_stage==1){
  if((uint32_t)(now-recovery_ms)<20u)return;
  g_camera.recovery_error=sensor_write(0x3008,0x02)?-2:0;
  g_camera.recovery_stage=0;progress_ms=now;
 }else if((uint32_t)(now-progress_ms)>=1500u && (uint32_t)(now-recovery_ms)>=3000u){
  recovery_ms=now;g_camera.restarts++;
  g_camera.recovery_error=sensor_write(0x3008,0x42)?-1:0;
  // Always attempt resume, even if a stop ACK was lost.
  g_camera.recovery_stage=1;
 }
}
int camera_init(void){
 direction_ready=direction_seq=0;initialized=0;output_word=0;last_frame=last_input=last_complete=0;marker_word=marker_dirty=0;g_camera.result=-100;
 g_camera.marker_valid=g_camera.marker_x=g_camera.marker_y=0;
 g_camera.displayed_frames=g_camera.input_frames=g_camera.complete_frames=0;
 g_camera.restarts=g_camera.recovery_stage=0;g_camera.recovery_error=0;
 g_camera.version=0x43415231u;monitor_started=0;
 XGpio_Config *config=XGpio_LookupConfig(CAMERA_GPIO_BASE);
 if(!config || XGpio_CfgInitialize(&camera_gpio,config,CAMERA_GPIO_BASE)!=0)return g_camera.result=-1;
 XGpio_SetDataDirection(&camera_gpio,1,0);XGpio_SetDataDirection(&camera_gpio,2,0xffffffffu);
 XGpio_Config *direction_config=XGpio_LookupConfig(DIRECTION_GPIO_BASE);
 if(!direction_config || XGpio_CfgInitialize(&direction_gpio,direction_config,DIRECTION_GPIO_BASE)!=0)return g_camera.result=-7;
 XGpio_SetDataDirection(&direction_gpio,1,0);XGpio_DiscreteWrite(&direction_gpio,1,0);direction_ready=1;
 initialized=1;write_bus();unsigned locked=0;
 for(unsigned i=0;i<100;i++){camera_poll();if((g_camera.status&12)==12){locked=1;break;}usleep(1000);}
 if(!locked)return g_camera.result=-2;
 // RST=module 3V3,PWDN=common GND; wait for XCLK and software-reset the sensor.
 usleep(50000);data_line(1);
 for(unsigned i=0;i<9;i++){clock_line(0);clock_line(1);}bus_stop();
 unsigned hi=0,lo=0;
 if(sensor_read(0x300a,&hi)||sensor_read(0x300b,&lo))return g_camera.result=-3;
 g_camera.sensor_id=(hi<<8)|lo;if(g_camera.sensor_id!=0x5640)return g_camera.result=-4;
 for(unsigned i=0;i<sizeof(camera_registers)/sizeof(camera_registers[0]);i++){
  unsigned reg=camera_registers[i]>>8,value=camera_registers[i]&255;g_camera.last_register=reg;
  if(sensor_write(reg,value))return g_camera.result=-5;
  usleep(reg==0x3008 && value==0x82?10000:100);
 }
 // Read back static timing/anti-flicker settings before enabling capture.
 // A mismatch does not silently enable capture with an unverified mode.
 static const unsigned verify[]={0x380803,0x380920,0x380a01,0x380bc2,0x460c22,0x382402,0x474020,0x303541,0x303669,0x380c07,0x380d64,
  0x380e02,0x380fe4,0x5001a3,0x3a0078,0x3a0202,0x3a03e0,
  0x3a1402,0x3a15e0,0x3a0800,0x3a096e,0x3a0a00,0x3a0b5c,
  0x3a0d08,0x3a0e06,0x3c01b4,0x3c0004,0x350300};
 for(unsigned i=0;i<sizeof(verify)/sizeof(verify[0]);i++){
  unsigned reg=verify[i]>>8,value=0;g_camera.last_register=reg;
  if(sensor_read(reg,&value)||value!=(verify[i]&255))return g_camera.result=-6;
 }
 output_word|=4;write_bus();camera_poll();return g_camera.result=0;
}
