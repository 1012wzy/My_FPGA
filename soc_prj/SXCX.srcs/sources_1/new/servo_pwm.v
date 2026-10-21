`timescale 1ns/1ps
// 50 Hz PWM with 12-bit microsecond targets, per-axis limits and acceleration.
// Actual outputs below are commanded pulse widths, NOT shaft position feedback.
module servo_pwm #(
 parameter integer CLOCKS_PER_US=100,
 parameter integer WATCHDOG_US=2000000,
 parameter integer MAX_STEP_US=12
)(input wire clk,resetn,input wire [1:0] enable,
 input wire heartbeat,hold_position,pan_center,input wire [11:0] pan_us,tilt_us,
 output reg pan_pwm,tilt_pwm,output reg fault,
 output reg [11:0] pan_actual_us,tilt_actual_us);
 reg [6:0] divider;
 reg [14:0] frame_us;
 reg [21:0] watchdog;
 reg last_heartbeat;
 reg signed [4:0] pan_velocity,tilt_velocity;
 // One velocity unit = 1us per 20ms frame. Acceleration = 2 units per frame; default speed 600us/s.
 function [16:0] advance;
 input [11:0] pos,target,lo,hi;
 input signed [4:0] velocity;
 input run;
 reg signed [12:0] p,t,d;
 reg signed [4:0] v;
 reg [12:0] ad;
 reg [4:0] av;
 reg [5:0] brake,accelerate_distance;
 begin
  p=$signed({1'b0,pos});t=$signed({1'b0,(target<lo?lo:(target>hi?hi:target))});v=velocity;
  if(!run) v=0;
  else begin
   d=t-p;ad=d<0?-d:d;av=v<0?-v:v;
   // Conservative stopping distance with deceleration 2us/frame/frame.
   // Odd speeds are included for target clamping and retargeting.
   case(av)
    0:begin brake=0;accelerate_distance=2;end
    1:begin brake=1;accelerate_distance=4;end
    2:begin brake=2;accelerate_distance=6;end
    3:begin brake=4;accelerate_distance=9;end
    4:begin brake=6;accelerate_distance=12;end
    5:begin brake=9;accelerate_distance=16;end
    6:begin brake=12;accelerate_distance=20;end
    7:begin brake=16;accelerate_distance=25;end
    8:begin brake=20;accelerate_distance=30;end
    9:begin brake=25;accelerate_distance=36;end
    10:begin brake=30;accelerate_distance=42;end
    11:begin brake=36;accelerate_distance=49;end
    default:begin brake=42;accelerate_distance=56;end
   endcase
   if(d==0)v=0;
   else if((d>0 && v<0)||(d<0 && v>0) || (ad<brake && av>0))
    v=av<=2?0:v+(v>0?-2:2);
   else if(av<MAX_STEP_US && (ad>=accelerate_distance || av==0))begin
    v=v+(d>0?2:-2);
    if(v>MAX_STEP_US)v=MAX_STEP_US;
    if(v< -MAX_STEP_US)v=-MAX_STEP_US;
   end
   if((d>0 && v>d)||(d<0 && v<d))begin p=t;v=0;end
   else p=p+v;
   if(p<lo)begin p=lo;v=0;end
   if(p>hi)begin p=hi;v=0;end
  end
  advance={v[4:0],p[11:0]};
 end
 endfunction
 wire [16:0] pan_next=advance(pan_actual_us,pan_center?12'd1500:pan_us,12'd500,12'd2500,pan_velocity,enable[0] && (pan_center || !hold_position) && !fault);
 wire [16:0] tilt_next=advance(tilt_actual_us,tilt_us,12'd1350,12'd2500,tilt_velocity,enable[1] && !hold_position && !fault);
 always @(posedge clk) begin
  if(!resetn)begin
   divider<=0;frame_us<=19999;pan_actual_us<=1500;tilt_actual_us<=1600;
   pan_velocity<=0;tilt_velocity<=0;
   watchdog<=0;last_heartbeat<=heartbeat;fault<=0;pan_pwm<=0;tilt_pwm<=0;
  end else begin
   last_heartbeat<=heartbeat;
   if(enable==0)begin watchdog<=0;fault<=0;end
   else if(heartbeat!=last_heartbeat)watchdog<=0;
   else if(divider==CLOCKS_PER_US-1 && !fault)begin
    if(watchdog==WATCHDOG_US-1)fault<=1;
    else watchdog<=watchdog+1'b1;
   end
   if(divider==CLOCKS_PER_US-1)begin
    divider<=0;
    if(frame_us==19999)begin
     frame_us<=0;
     {pan_velocity,pan_actual_us}<=pan_next;
     {tilt_velocity,tilt_actual_us}<=tilt_next;
     pan_pwm<=enable[0] && !fault;tilt_pwm<=enable[1] && !fault;
    end else begin
     frame_us<=frame_us+1'b1;
     if(frame_us==pan_actual_us-1'b1)pan_pwm<=0;
     if(frame_us==tilt_actual_us-1'b1)tilt_pwm<=0;
    end
   end else divider<=divider+1'b1;
   if(!enable[0] || fault)pan_velocity<=0;
   if(!enable[1] || fault)tilt_velocity<=0;
   if(!enable[0] || fault || (divider==CLOCKS_PER_US-1 && watchdog==WATCHDOG_US-1 && heartbeat==last_heartbeat))pan_pwm<=0;
   if(!enable[1] || fault || (divider==CLOCKS_PER_US-1 && watchdog==WATCHDOG_US-1 && heartbeat==last_heartbeat))tilt_pwm<=0;
  end
 end
endmodule
