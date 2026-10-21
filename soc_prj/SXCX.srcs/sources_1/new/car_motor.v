`timescale 1ns/1ps
// BUT1: active-low, press once per release. Hardware defaults to display mode.
// GPIO command: left[7:0],right[15:8],forward A/B[16/17],enable18,
// heartbeat19,mode ACK20,fresh accepted audio sequence21.
// GPIO status: mode0,key-down1,driving2,HB-timeout3,mode-epoch[7:4],
// actual duty L[15:8]/R[23:16],signature[31:24]=0xC1.
module car_motor #(
 parameter integer CLOCK_HZ=100000000,
 parameter integer PWM_HZ=20000,
 parameter integer DEBOUNCE_CYCLES=2000000,
 parameter integer HEARTBEAT_CYCLES=25000000,
 parameter integer SOURCE_CYCLES=30000000,
 parameter integer MAX_DUTY=115
)(input wire clk,resetn,key_n,input wire [31:0] control,
 output wire [31:0] status,output reg car_mode,
 output wire pwm_a,ain1,ain2,pwm_b,bin1,bin2,stby,
 output wire mode_led,drive_led);
 localparam integer PERIOD=CLOCK_HZ/PWM_HZ;
 (* ASYNC_REG="TRUE" *) reg key_meta,key_sync;
 reg key_stable,key_armed,key_previous;
 reg [31:0] debounce;
 reg [3:0] epoch;
 reg hb_last,source_last,hb_seen,source_seen;
 reg [31:0] hb_age,source_age;
 reg [31:0] pwm_count;
 reg [7:0] left_duty,right_duty;
 reg forward_a,forward_b;
 wire mode_event=(key_sync==key_previous && key_sync!=key_stable && debounce==DEBOUNCE_CYCLES-1 && !key_sync && key_armed);
 wire request=car_mode && control[20] && control[18] && key_sync && key_stable;
 wire alive=hb_seen && hb_age<HEARTBEAT_CYCLES;
 wire fresh=source_seen && source_age<SOURCE_CYCLES;
 wire run=resetn && request && alive && fresh;
 wire [31:0] left_ticks=(left_duty*PERIOD)>>8;
 wire [31:0] right_ticks=(right_duty*PERIOD)>>8;
 assign stby=run && (left_duty!=0 || right_duty!=0);
 assign pwm_a=stby && pwm_count<left_ticks;
 assign pwm_b=stby && pwm_count<right_ticks;
 assign ain1=stby && forward_a;
 assign ain2=stby && !forward_a;
 assign bin1=stby && forward_b;
 assign bin2=stby && !forward_b;
 assign mode_led=car_mode;
 assign drive_led=stby;
 assign status={8'hc1,(stby?right_duty:8'd0),(stby?left_duty:8'd0),epoch,!alive,stby,!key_sync,car_mode};
 always @(posedge clk)begin
  if(!resetn)begin
   key_meta<=1;key_sync<=1;key_stable<=1;key_armed<=0;key_previous<=1;debounce<=0;
   car_mode<=0;epoch<=0;
   hb_last<=0;source_last<=0;hb_seen<=0;source_seen<=0;hb_age<=HEARTBEAT_CYCLES;source_age<=SOURCE_CYCLES;
   pwm_count<=0;left_duty<=0;right_duty<=0;forward_a<=1;forward_b<=1;
  end else begin
   key_meta<=key_n;key_sync<=key_meta;
   key_previous<=key_sync;
   if(key_sync!=key_previous)debounce<=0;
   else if(debounce<DEBOUNCE_CYCLES)begin
    debounce<=debounce+1;
    if(debounce==DEBOUNCE_CYCLES-1)begin
     key_stable<=key_sync;
     if(key_sync)key_armed<=1;
     else begin
      if(key_armed)begin car_mode<=!car_mode;epoch<=epoch+1'b1;end
      key_armed<=0;
     end
    end
   end
   hb_last<=control[19];source_last<=control[21];
   if(!request || mode_event)begin
    hb_seen<=0;source_seen<=0;hb_age<=HEARTBEAT_CYCLES;source_age<=SOURCE_CYCLES;
   end else begin
    if(control[19]!=hb_last)begin hb_seen<=1;hb_age<=0;end
    else if(hb_age<HEARTBEAT_CYCLES)hb_age<=hb_age+1;
    if(control[21]!=source_last)begin source_seen<=1;source_age<=0;end
    else if(source_age<SOURCE_CYCLES)source_age<=source_age+1;
   end
   if(!run)begin
    pwm_count<=0;left_duty<=0;right_duty<=0;
   end else if(pwm_count==PERIOD-1)begin
    pwm_count<=0;
    left_duty<=control[7:0]>MAX_DUTY?MAX_DUTY:control[7:0];
    right_duty<=control[15:8]>MAX_DUTY?MAX_DUTY:control[15:8];
    forward_a<=control[16];forward_b<=control[17];
   end else pwm_count<=pwm_count+1;
  end
 end
endmodule
