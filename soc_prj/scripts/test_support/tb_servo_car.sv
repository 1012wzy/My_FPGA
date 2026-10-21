`timescale 1ns/1ps
module tb_servo_car;
 reg clk=0,resetn=0,heartbeat=0,hold_position=0,pan_center=0;
 reg [1:0] enable=3;reg [11:0] pan_us=2000,tilt_us=1800;
 wire pan_pwm,tilt_pwm,fault;wire [11:0] pan_actual_us,tilt_actual_us;
 always #5 clk=~clk;
 servo_pwm #(.CLOCKS_PER_US(1),.WATCHDOG_US(2000000)) dut(.*);
 task frames(input integer n);
  repeat(n)begin repeat(20000)@(posedge clk);heartbeat=~heartbeat;#1;end
 endtask
 initial begin
  repeat(4)@(negedge clk);resetn=1;frames(70);
  if(pan_actual_us!=2000 || tilt_actual_us!=1800)$fatal(1,"normal pan/tilt");
  pan_center=1;hold_position=1;frames(70);
  if(pan_actual_us!=1500 || tilt_actual_us!=1800)$fatal(1,"center while tilt held");
  hold_position=0;tilt_us=2000;pan_us=2500;frames(40);
  if(pan_actual_us!=1500 || tilt_actual_us!=2000)$fatal(1,"tilt must track with pan locked");
  pan_center=0;pan_us=1600;frames(25);
  if(pan_actual_us!=1600)$fatal(1,"return to mode1 pan tracking");
  $display("PASS: mode1 pan/tilt, mode2 independent pan center under hold, tilt tracking, return to display mode");$finish;
 end
 initial begin #50000000;$fatal(1,"timeout");end
endmodule
