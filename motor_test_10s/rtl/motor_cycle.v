`timescale 1ns/1ps
// Standalone wheel test. No sound/PS/DDR dependency. Press BUT1 to start/stop.
module motor_cycle #(
 parameter integer CLOCK_HZ=100000000, PWM_HZ=20000,
 parameter integer DRIVE_CYCLES=1000000000, GAP_CYCLES=100000000,
 parameter integer DEBOUNCE_CYCLES=2000000,
 parameter integer DUTY_PERCENT=25,
 parameter LEFT_FORWARD=1'b1, RIGHT_FORWARD=1'b1
)(input wire clk,resetn,key_n,
 output wire pwm_a,ain1,ain2,pwm_b,bin1,bin2,stby,
 output wire running_led,reverse_led,output reg [2:0] phase);
 localparam IDLE=0,FWD=1,GAP_REV=2,REV=3,GAP_FWD=4;
 localparam integer PERIOD=CLOCK_HZ/PWM_HZ;
 localparam integer HIGH_TICKS=PERIOD*DUTY_PERCENT/100;
 (* ASYNC_REG="TRUE" *) reg key_meta,key_sync;
 reg key_previous,key_stable,key_armed;
 reg [31:0] debounce,elapsed,pwm_count;
 wire press=(key_sync==key_previous && key_sync!=key_stable && debounce==DEBOUNCE_CYCLES-1 && !key_sync && key_armed);
 wire released=key_sync && key_stable;
 wire drive=resetn && released && (phase==FWD || phase==REV);
 wire fa=(phase==FWD)?LEFT_FORWARD:!LEFT_FORWARD;
 wire fb=(phase==FWD)?RIGHT_FORWARD:!RIGHT_FORWARD;
 assign stby=drive;
 assign pwm_a=drive && pwm_count<HIGH_TICKS;
 assign pwm_b=pwm_a;
 assign ain1=drive && fa;
 assign ain2=drive && !fa;
 assign bin1=drive && fb;
 assign bin2=drive && !fb;
 assign running_led=resetn && phase!=IDLE;
 assign reverse_led=resetn && (phase==REV || phase==GAP_FWD);
 always @(posedge clk)begin
  if(!resetn)begin
   key_meta<=1;key_sync<=1;key_previous<=1;key_stable<=1;key_armed<=0;
   debounce<=0;elapsed<=0;pwm_count<=0;phase<=IDLE;
  end else begin
   key_meta<=key_n;key_sync<=key_meta;key_previous<=key_sync;
   if(key_sync!=key_previous)debounce<=0;
   else if(debounce<DEBOUNCE_CYCLES)begin
    debounce<=debounce+1;
    if(debounce==DEBOUNCE_CYCLES-1)begin
     key_stable<=key_sync;
     if(key_sync)key_armed<=1;
     else key_armed<=0;
    end
   end
   if(!drive || pwm_count==PERIOD-1)pwm_count<=0;
   else pwm_count<=pwm_count+1;
   if(press)begin
    phase<=(phase==IDLE)?FWD:IDLE;elapsed<=0;pwm_count<=0;
   end else if(released)begin
    case(phase)
     FWD,REV:if(elapsed==DRIVE_CYCLES-1)begin
      elapsed<=0;phase<=(phase==FWD)?GAP_REV:GAP_FWD;
     end else elapsed<=elapsed+1;
     GAP_REV,GAP_FWD:if(elapsed==GAP_CYCLES-1)begin
      elapsed<=0;phase<=(phase==GAP_REV)?REV:FWD;
     end else elapsed<=elapsed+1;
     default:begin phase<=IDLE;elapsed<=0;end
    endcase
   end
  end
 end
endmodule
