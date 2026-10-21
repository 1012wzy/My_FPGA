#include <stdint.h>
#include <math.h>
#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xil_cache.h"
#include "xiltimer.h"
#include "sleep.h"
#include "doa.h"
#include "servo.h"
#include "servo_startup.h"
#include "camera.h"
#include "sound_marker.h"
#include "sound_marker_config.h"
#include "background.h"
#include "car.h"
#define CAR_GPIO_BASE 0x41230000U
#define DMA_BASE 0x40400000U
#define GPIO_BASE 0x41200000U
static XAxiDma dma;
static XGpio gpio,car_gpio;
static Car car;
static int car_gpio_ready;
static uint32_t last_car_control=0xffffffffu;
volatile uint32_t g_car[16] __attribute__((aligned(64)));
static Servo servo;
static SoundMarker marker;
static Background background;
static unsigned capture_on,heartbeat;
// Dedicated cache line: debugger owns the request word; firmware never writes it.
// Download initializes mode0 (automatic tracking). mode1 only holds current pose.
volatile uint32_t g_marker_hold[16] __attribute__((aligned(64)))={0x484f4c44u,0};
static unsigned marker_hold_mode;
static void marker_hold_poll(void){
 Xil_DCacheInvalidateRange((UINTPTR)g_marker_hold,sizeof(g_marker_hold));
 unsigned request=g_marker_hold[1];
 if(g_marker_hold[0]!=0x484f4c44u || request>1u || request==marker_hold_mode)return;
 marker_hold_mode=request;
 servo_hold(&servo);
}

static uint32_t telemetry_ms;
static uint32_t heartbeat_ms,last_control=0xffffffffu;
static int32_t records[AUDIO_WORDS] __attribute__((aligned(64)));
// Optional debugger visibility; normal operation requires no UART or terminal.
struct TrackingTelemetry {
 uint32_t state,blocks,compute_ms,pl_status;
 int fault_code,az,el,valid,noise_rms,pan_target_us,tilt_target_us,pan_pwm_us,tilt_pwm_us;
 uint32_t capture_ms,cycle_ms,valid_blocks,max_compute_ms;
};
volatile struct TrackingTelemetry g_tracking __attribute__((aligned(64)));
// Shared quality diagnosis for marker and servo; DOA math is unchanged.
// reason,rms,threshold,coherence*1000,margin*1000,tonality*1000,az*1000,el*1000.
volatile int32_t g_marker[8] __attribute__((aligned(64)));
static int32_t diagnostic_value(float value){return isfinite(value)?(int32_t)value:0;}
static uint32_t millis(void){XTime t;XTime_GetTime(&t);return (uint32_t)(t/(COUNTS_PER_SECOND/1000));}
static int expired(XTime start,unsigned seconds){XTime t;XTime_GetTime(&t);return t-start>(XTime)COUNTS_PER_SECOND*seconds;}
static void write_car_control(void){
 if(!car_gpio_ready)return;
 uint32_t v=car_command(&car,heartbeat);
 if(v!=last_car_control){XGpio_DiscreteWrite(&car_gpio,1,v);last_car_control=v;}
}
static void write_control(void){uint32_t v=servo_control(&servo,heartbeat,capture_on);if(v!=last_control){XGpio_DiscreteWrite(&gpio,1,v);last_control=v;}}
static void set_capture(unsigned on){capture_on=on;write_control();}
static void stop_on_fault(int code){car.allowed=0;car_stop(&car);write_car_control();marker_init(&marker);camera_set_marker(0,0,0);camera_set_direction(0,0,0);servo_off(&servo);capture_on=0;write_control();g_tracking.fault_code=code;g_tracking.state=3;}
static void service(void){
 uint32_t now=millis();
 if((uint32_t)(now-heartbeat_ms)>=20){
  heartbeat_ms=now;heartbeat^=1;
  // Servo heartbeat/feedback are serviced before optional display telemetry.
  uint32_t status=XGpio_DiscreteRead(&gpio,2);
  g_tracking.pl_status=status;servo_feedback(&servo,status);marker_hold_poll();
  if(status&16)stop_on_fault(-6);
  if(car_gpio_ready){
   uint32_t cs=XGpio_DiscreteRead(&car_gpio,2);
   int changed=car_poll(&car,cs,servo.actual[0],g_tracking.state==2 && !MARKER_CALIBRATION_HOLD_SERVOS && !marker_hold_mode,now);
   if(changed){servo_hold(&servo);marker_init(&marker);camera_set_marker(0,0,0);camera_set_direction(0,0,0);}
   if(car.mode)servo.target[0]=CAR_PAN_CENTER_US;
   write_car_control();
   g_car[0]=0x43415231u;g_car[1]=car.mode+1u;g_car[2]=car.stage;g_car[3]=cs;
   g_car[4]=(uint32_t)car.target_left;g_car[5]=(uint32_t)car.target_right;
   g_car[6]=(uint32_t)car.left;g_car[7]=(uint32_t)car.right;
   g_car[8]=car.fresh;g_car[9]=car.fresh?(uint32_t)(now-car.last_sample_ms):0xffffffffu;
   g_car[10]=(uint32_t)(int32_t)lroundf(car.steer*1000);g_car[11]=car.centered;
   g_car[12]=CAR_BASE_DUTY;g_car[13]=CAR_TURN_DUTY;g_car[14]=CAR_LOSS_MS;g_car[15]=car.epoch;
  }
  servo_tick(&servo,now);write_control();
  marker_tick(&marker,now);camera_set_marker(marker.valid,marker.x,marker.y);camera_poll();camera_maintain(now);
  if((uint32_t)(now-telemetry_ms)>=100){
   telemetry_ms=now;
   Xil_DCacheFlushRange((UINTPTR)g_car,sizeof(g_car));
   Xil_DCacheFlushRange((UINTPTR)&g_camera,sizeof(g_camera));
   Xil_DCacheFlushRange((UINTPTR)&g_tracking,sizeof(g_tracking));
   Xil_DCacheFlushRange((UINTPTR)g_marker,sizeof(g_marker));
  }
 }
 servo_tick(&servo,now);write_control();
}
static void wait_ms(unsigned duration){uint32_t t=millis();while((uint32_t)(millis()-t)<duration){service();usleep(1000);}}
static int startup_settle(unsigned duration){
 uint32_t t=millis();
 while((uint32_t)(millis()-t)<duration){
  service();if(g_tracking.state==3)return -1;usleep(1000);
 }
 return g_tracking.state==3 ? -1 : 0;
}
static int capture(void){
 set_capture(0);usleep(10);
 Xil_DCacheFlushRange((UINTPTR)records,sizeof(records));
 if(XAxiDma_SimpleTransfer(&dma,(UINTPTR)records,sizeof(records),XAXIDMA_DEVICE_TO_DMA)!=XST_SUCCESS)return -1;
 set_capture(1);XTime start;XTime_GetTime(&start);
 while(XAxiDma_Busy(&dma,XAXIDMA_DEVICE_TO_DMA)){
  service();if(g_tracking.state==3){set_capture(0);return -6;}
  u32 sr=XAxiDma_ReadReg(DMA_BASE,XAXIDMA_RX_OFFSET+XAXIDMA_SR_OFFSET);
  if(sr & XAXIDMA_ERR_ALL_MASK){set_capture(0);return -2;}
  if(expired(start,2)){set_capture(0);return -3;}
 }
 u32 status=XGpio_DiscreteRead(&gpio,2);set_capture(0);
 Xil_DCacheInvalidateRange((UINTPTR)records,sizeof(records));
 if((status&14)!=2)return -4;
 for(unsigned n=0;n<AUDIO_FRAMES;n++)if((uint32_t)records[n*8]!=n)return -5;
 return 0;
}
int main(void){
 car_init(&car);
 XGpio_Config *cc=XGpio_LookupConfig(CAR_GPIO_BASE);
 if(!cc || XGpio_CfgInitialize(&car_gpio,cc,CAR_GPIO_BASE)!=XST_SUCCESS){g_tracking.state=3;g_tracking.fault_code=-12;return 1;}
 XGpio_SetDataDirection(&car_gpio,1,0);XGpio_SetDataDirection(&car_gpio,2,0xffffffff);
 XGpio_DiscreteWrite(&car_gpio,1,0);car_gpio_ready=1;
 if((XGpio_DiscreteRead(&car_gpio,2)>>24)!=0xc1u){g_tracking.state=3;g_tracking.fault_code=-13;return 1;}
 XAxiDma_Config *dc=XAxiDma_LookupConfig(DMA_BASE);
 XGpio_Config *gc=XGpio_LookupConfig(GPIO_BASE);
 if(!dc||!gc || XAxiDma_CfgInitialize(&dma,dc)!=XST_SUCCESS || XGpio_CfgInitialize(&gpio,gc,GPIO_BASE)!=XST_SUCCESS){g_tracking.state=3;g_tracking.fault_code=-10;return 1;}
 XGpio_SetDataDirection(&gpio,1,0);XGpio_SetDataDirection(&gpio,2,0xffffffff);
 servo_init(&servo);marker_init(&marker);write_control();
 if(XAxiDma_HasSg(&dma)){stop_on_fault(-11);return 1;}
 XAxiDma_IntrDisable(&dma,XAXIDMA_IRQ_ALL_MASK,XAXIDMA_DEVICE_TO_DMA);
 doa_init();camera_init();g_tracking.state=1;wait_ms(2000);
 // Measure the operating noise floor AFTER both servos are powered and settled.
 if(servo_startup(&servo,startup_settle,write_control,millis)!=0)return 1;
 servo.tracking=0;servo.hold=1;write_control();background_init(&background);
 float noise=0;
 while(1){
  service();
  if(g_tracking.state==3){wait_ms(20);continue;} // Latched fault: explicit restart required.
  unsigned cycle_epoch=car.epoch;
  uint32_t cycle_started_ms=millis();
  int rc=capture();
  g_tracking.capture_ms=millis()-cycle_started_ms;
  if(rc){stop_on_fault(rc);continue;}
  DoaResult r;XTime before,after;XTime_GetTime(&before);
  if(doa_process(records,noise,&r)){stop_on_fault(-5);continue;}
  XTime_GetTime(&after);service();if(g_tracking.state==3)continue;
  g_tracking.compute_ms=(unsigned)((after-before)*1000/(COUNTS_PER_SECOND));
  if(g_tracking.compute_ms>g_tracking.max_compute_ms)g_tracking.max_compute_ms=g_tracking.compute_ms;
  if(!background.ready){
   if(background_add(&background,r.rms)){
    noise=background.noise_rms;g_tracking.noise_rms=(int)noise;
    marker_init(&marker);servo_start(&servo,millis());write_control();g_tracking.state=2;
   }
   continue;
  }
  if(cycle_epoch!=car.epoch){car_stop(&car);write_car_control();continue;}
  // Continuous acquisition, no 600ms mechanical pause. PL interpolates targets.
  servo_feedback(&servo,XGpio_DiscreteRead(&gpio,2));
  uint32_t observed_ms=millis();
  unsigned marker_reason=marker_update(&marker,&r,noise,observed_ms);
  if(!MARKER_CALIBRATION_HOLD_SERVOS && !marker_hold_mode){
   // Fresh accepted observation only. A held SOS or rejected acoustic peak
   // never renews servo motion. Use the raw accepted angle to retain P response.
   if(car.mode){
    servo_observe_confirmed(&servo,marker.accepted,0.f,r.el,observed_ms);
    servo.target[0]=CAR_PAN_CENTER_US;
   }else servo_observe_confirmed(&servo,marker.accepted,r.az,r.el,observed_ms);
  }
  write_control();
  car_observe(&car,marker.accepted,r.az,cycle_started_ms+g_tracking.capture_ms/2u,observed_ms);
  write_car_control();
  // Publish immediately; do not wait for the next 20ms heartbeat slice.
  camera_set_marker(marker.valid,marker.x,marker.y);camera_poll();
  camera_set_direction(marker.locked,(int)lroundf(marker.az),(int)lroundf(marker.el));
  g_marker[0]=(int32_t)marker_reason;
  g_marker[1]=diagnostic_value(r.rms);
  float required=marker_required_level(&r,noise);
  if(marker_reason==0 && marker_reject_reason(&r,noise)==1u)required=fmaxf(MARKER_MIN_RMS,noise*MARKER_CONTINUE_NOISE_RATIO);
  g_marker[2]=diagnostic_value(required);
  g_marker[3]=diagnostic_value(r.coherence*1000);g_marker[4]=diagnostic_value(r.margin*1000);
  g_marker[5]=diagnostic_value(r.tonality*1000);
  g_marker[6]=diagnostic_value(r.az*1000);g_marker[7]=diagnostic_value(r.el*1000);
  g_tracking.blocks++;g_tracking.az=(int)marker.az;g_tracking.el=(int)marker.el;g_tracking.valid=marker_reason==0;
  if(marker_reason==0)g_tracking.valid_blocks++;
  g_tracking.cycle_ms=millis()-cycle_started_ms;
  g_tracking.pan_target_us=servo.target[0];g_tracking.tilt_target_us=servo.target[1];
  g_tracking.pan_pwm_us=servo.actual[0];g_tracking.tilt_pwm_us=servo.actual[1];
 }
}
