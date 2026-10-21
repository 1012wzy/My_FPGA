`timescale 1ns/1ps
module tb_motor_cycle;
 reg clk=0,resetn=0,key_n=0;
 wire pwm_a,ain1,ain2,pwm_b,bin1,bin2,stby,running_led,reverse_led;
 wire [2:0] phase;
 always #5 clk=~clk;
 motor_cycle #(.CLOCK_HZ(1000),.PWM_HZ(50),.DRIVE_CYCLES(10000),.GAP_CYCLES(1000),.DEBOUNCE_CYCLES(4)) dut(.*);
 task cycles(input integer n);repeat(n)begin @(posedge clk);#2;end endtask
 task press;begin @(negedge clk);key_n=0;cycles(12);@(negedge clk);key_n=1;cycles(12);end endtask
 integer ticks[0:4]; integer old_phase;integer transitions=0;integer high_count;
 integer seen_forward=0,seen_reverse=0;
 initial for(integer i=0;i<5;i++)ticks[i]=0;
 always @(posedge clk)begin
  old_phase=phase;
  if(resetn && dut.released && phase!=0)ticks[phase]=ticks[phase]+1;
  #1;
  if(!resetn)begin for(integer i=0;i<5;i++)ticks[i]=0;end
  else if(phase!=old_phase)begin
   if((old_phase==1 && phase==2)||(old_phase==3 && phase==4))begin
    if(ticks[old_phase]!=10000)$fatal(1,"drive interval %0d != 10000",ticks[old_phase]);
    transitions=transitions+1;
   end
   if((old_phase==2 && phase==3)||(old_phase==4 && phase==1))begin
    if(ticks[old_phase]!=1000)$fatal(1,"coast interval %0d != 1000",ticks[old_phase]);
    transitions=transitions+1;
   end
   ticks[old_phase]=0;
  end
  if(!resetn && stby)$fatal(1,"reset did not inhibit");
  if(!stby && (pwm_a || pwm_b || ain1 || ain2 || bin1 || bin2))$fatal(1,"outputs active in coast/stop");
  if(stby)begin
   if(pwm_a!==pwm_b)$fatal(1,"wheel PWM mismatch");
   if(phase==1 && (!ain1 || ain2 || !bin1 || bin2))$fatal(1,"forward polarity");
   if(phase==3 && (ain1 || !ain2 || bin1 || !bin2))$fatal(1,"reverse polarity");
  end
 end
 initial begin
  cycles(5);resetn=1;cycles(20);
  if(phase!=0 || stby)$fatal(1,"held button on boot started test");
  @(negedge clk);key_n=1;cycles(12);
  @(negedge clk);key_n=0;cycles(2);@(negedge clk);key_n=1;cycles(12);
  if(phase!=0)$fatal(1,"bounce started test");
  press();if(phase!=1 || !stby)$fatal(1,"first press did not start forward");
  high_count=0;repeat(200)begin cycles(1);if(pwm_a)high_count++;end
  if(high_count!=50)$fatal(1,"25 percent PWM: %0d/200",high_count);
  wait(transitions==8);cycles(10);
  if(phase!=1)$fatal(1,"two loops did not return to forward");
  @(negedge clk);key_n=0;cycles(3);
  if(stby)$fatal(1,"raw press did not inhibit before debounce");
  cycles(50);if(phase!=0)$fatal(1,"long press restarted test");
  @(negedge clk);key_n=1;cycles(15);if(stby)$fatal(1,"release restarted test");
  press();if(phase!=1 || !stby)$fatal(1,"restart not forward");
  @(negedge clk);resetn=0;cycles(2);if(stby || phase!=0)$fatal(1,"reset while running");
  resetn=1;cycles(15);if(phase!=0)$fatal(1,"reset auto-restarted");
  $display("PASS: default off, boot-held button, debounce, exact 10s/1s/10s/1s scaled intervals over two loops, 25 percent PWM, polarity, immediate inhibit, long-press stop, restart and reset");
  $finish;
 end
 initial begin #2000000;$fatal(1,"watchdog");end
endmodule
