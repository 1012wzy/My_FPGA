`timescale 1ns/1ps
module tb_servo_pwm;
 reg clk=0;always #5 clk=~clk;
 reg resetn=0,hb=0,hold_position=0;reg [1:0] en=0;
 reg [11:0] pan=1500,tilt=1600;wire pp,tp,fault;wire [11:0] pa,ta;
 servo_pwm #(.CLOCKS_PER_US(1),.WATCHDOG_US(120000)) dut(
 .clk(clk),.resetn(resetn),.enable(en),.pan_center(1'b0),.heartbeat(hb),.hold_position(hold_position),
 .pan_us(pan),.tilt_us(tilt),.pan_pwm(pp),.tilt_pwm(tp),.fault(fault),.pan_actual_us(pa),.tilt_actual_us(ta));
 integer cp,ct,oldp=1500,oldt=1600,prevp=0,prevt=0;
 time previous_start=0;
 task frame;
 begin
  @(posedge pp);#1;
  if(previous_start && $time-previous_start!=200000)$fatal(1,"not 50Hz scaled period");
  previous_start=$time;
  if(pa<500||pa>2500||ta<1350||ta>2500)$fatal(1,"range");
  if($signed({1'b0,pa})-oldp>12 || oldp-$signed({1'b0,pa})>12)$fatal(1,"pan speed");
  if($signed({1'b0,ta})-oldt>12 || oldt-$signed({1'b0,ta})>12)$fatal(1,"tilt speed");
  if(dut.pan_velocity-prevp>2 || prevp-dut.pan_velocity>2)$fatal(1,"pan acceleration p=%0d v=%0d previous=%0d",pa,dut.pan_velocity,prevp);
  if(dut.tilt_velocity-prevt>2 || prevt-dut.tilt_velocity>2)$fatal(1,"tilt acceleration");
  oldp=pa;oldt=ta;prevp=dut.pan_velocity;prevt=dut.tilt_velocity;
  cp=1;ct=tp?1:0;
  repeat(2599)begin @(posedge clk);#1;if(pp)cp++;if(tp)ct++;end
  if(cp!=pa || ct!=(en[1]?ta:0))$fatal(1,"pulse width mismatch: %0d/%0d vs %0d/%0d",cp,ct,pa,ta);
  @(negedge clk);hb=~hb;
 end endtask
 initial begin
  repeat(5)@(negedge clk);resetn=1;repeat(21000)@(negedge clk);
  if(pp||tp||fault)$fatal(1,"reset off");
  en=3;frame();if(pa!=1500||ta!=1600)$fatal(1,"startup");
  pan=3000;tilt=4095;repeat(100)frame();
  if(pa!=2500||ta!=2500)$fatal(1,"12-bit upper clamp/arrival");
  // Retarget during the 2500us high pulse: it must complete unaltered.
  @(posedge pp);#1;previous_start=0;repeat(100)@(negedge clk);pan=0;tilt=0;
  repeat(2399)@(negedge clk);if(!pp||!tp)$fatal(1,"mid-frame shortened");
  repeat(2)@(negedge clk);if(pp||tp)$fatal(1,"mid-frame lengthened");
  repeat(185)frame();if(pa!=500||ta!=1350)$fatal(1,"asymmetric lower limits");
  // Every small target increment (odd and even) must settle without stalling.
  for(integer delta=1;delta<=24;delta=delta+1)begin
   pan=pa+delta;tilt=ta+delta;repeat(12)frame();
   if(pa!=pan||ta!=tilt)$fatal(1,"small target arrival delta=%0d",delta);
  end
  // Retarget while still accelerating/cruising, not only after arrival.
  pan=2500;tilt=2500;repeat(10)frame();
  pan=500;tilt=1350;repeat(65)frame();
  if(pa!=500||ta!=1350)$fatal(1,"moving reversal arrival");
  pan=2500;tilt=2500;repeat(20)frame();
  hold_position=1;prevp=0;prevt=0;repeat(3)frame();
  if(dut.pan_velocity||dut.tilt_velocity)$fatal(1,"hold must stop slewing");
  en=1;repeat(2)frame();if(tp)$fatal(1,"axis enable");
  // No heartbeats: watchdog must latch, even if heartbeat later resumes.
  repeat(121000)@(negedge clk);if(!fault||pp||tp)$fatal(1,"watchdog");
  hb=~hb;repeat(21000)@(negedge clk);if(!fault||pp)$fatal(1,"fault not latched");
  en=0;repeat(2)@(negedge clk);if(fault)$fatal(1,"fault clear");
  en=2;wait(tp);@(negedge clk);en=0;@(negedge clk);if(pp||tp)$fatal(1,"immediate disable");
  $display("PASS: 12-bit 500..2500/1350..2500, PWM period/width, acceleration/speed, ramp arrival/reversal, atomic writes, hold, independent enable, watchdog");$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
