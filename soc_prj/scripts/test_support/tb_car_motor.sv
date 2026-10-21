`timescale 1ns/1ps
module tb_car_motor;
 reg clk=0,resetn=0,key_n=1;
 reg [31:0] control=0;
 wire [31:0] status;wire car_mode,pwm_a,ain1,ain2,pwm_b,bin1,bin2,stby,mode_led,drive_led;
 always #5 clk=~clk;
 car_motor #(.CLOCK_HZ(1000000),.PWM_HZ(20000),.DEBOUNCE_CYCLES(4),.HEARTBEAT_CYCLES(250),.SOURCE_CYCLES(300)) dut(.*);
 task cycles(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task press;begin key_n=0;cycles(12);key_n=1;cycles(12);end endtask
 task feed(input integer n,input bit hb,input bit source);
  for(integer i=0;i<n;i=i+1)begin
   @(negedge clk);
   if(hb && i%40==0)control[19]=!control[19];
   if(source && i%100==0)control[21]=!control[21];
   cycles(1);
  end
 endtask
 integer high_count;
 initial begin
  cycles(4);resetn=1;cycles(12);
  if(car_mode || stby || pwm_a || pwm_b)$fatal(1,"power-up not stopped");
  key_n=0;cycles(2);key_n=1;cycles(12);
  if(car_mode)$fatal(1,"key bounce toggled mode");
  press();if(!car_mode)$fatal(1,"button did not select car");
  control=(1<<20)|(1<<18)|(3<<16)|(64<<8)|64;
  cycles(60);if(stby)$fatal(1,"stale command started motors");
  feed(100,1,1);if(!stby)$fatal(1,"fresh control did not start");
  high_count=0;
  for(integer i=0;i<200;i=i+1)begin
   @(negedge clk);if(i%40==0)control[19]=!control[19];if(i%100==0)control[21]=!control[21];
   cycles(1);if(pwm_a)high_count=high_count+1;
  end
  if(high_count!=48)$fatal(1,"PWM period/duty mismatch %0d",high_count);
  if(!ain1 || ain2 || !bin1 || bin2)$fatal(1,"forward polarity");
  control[15:0]=16'hffff;feed(100,1,1);
  if(status[23:8]!=16'h7373)$fatal(1,"hardware duty cap");
  feed(360,1,0);if(stby || pwm_a || pwm_b)$fatal(1,"stale audio kept moving despite heartbeat");
  feed(100,1,1);if(!stby)$fatal(1,"fresh source recovery");
  feed(300,0,1);if(stby)$fatal(1,"missing CPU heartbeat kept moving");
  feed(100,1,1);if(!stby)$fatal(1,"fresh recovery");
  // Press stops on synchronized raw low, before debounce; held button toggles once.
  key_n=0;cycles(3);if(stby)$fatal(1,"button failed immediate inhibit");
  cycles(100);if(car_mode)$fatal(1,"long press repeated");
  key_n=1;cycles(12);press();if(!car_mode)$fatal(1,"second mode selection");
  cycles(100);if(stby)$fatal(1,"old source replay after mode transition");
  feed(100,1,1);if(!stby)$fatal(1,"new source after transition");
  control[18]=0;cycles(1);if(stby || pwm_a || pwm_b)$fatal(1,"disable");
  resetn=0;cycles(2);if(car_mode || stby)$fatal(1,"reset");
  // Button held throughout reset cannot cause an unsolicited mode change.
  key_n=0;resetn=1;cycles(100);if(car_mode)$fatal(1,"held-at-boot key");
  key_n=1;cycles(12);press();if(!car_mode)$fatal(1,"release-to-arm");
  $display("PASS: car RTL button debounce/one-press/boot-hold, 20kHz PWM, cap, source lease, heartbeat, mode/disable/reset interlocks");$finish;
 end
 initial begin #200000;$fatal(1,"timeout");end
endmodule
