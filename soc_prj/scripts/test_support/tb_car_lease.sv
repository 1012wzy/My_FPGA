`timescale 1ns/1ps
module tb_car_lease;
 reg clk=0,resetn=0,key_n=1;reg [31:0] control=0;
 wire [31:0] status;wire car_mode,pwm_a,ain1,ain2,pwm_b,bin1,bin2,stby,mode_led,drive_led;
 reg [31:0] trace_words[0:140];
 always #5 clk=~clk;
 // 10 cycles/model-ms: hardware watchdog durations remain 250ms and 300ms.
 car_motor #(.CLOCK_HZ(10000),.PWM_HZ(100),.DEBOUNCE_CYCLES(4),.HEARTBEAT_CYCLES(2500),.SOURCE_CYCLES(3000)) dut(.*);
 task cycles(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 initial begin
  $readmemh("car_lease_trace.hex",trace_words);
  cycles(4);resetn=1;cycles(12);key_n=0;cycles(12);key_n=1;cycles(12);
  if(!car_mode)$fatal(1,"mode2 entry");
  for(integer i=0;i<=140;i++)begin
   @(negedge clk);control=trace_words[i];cycles(200);
   if(i>=34 && i<120)begin
    if(!stby || !ain1 || ain2 || !bin1 || bin2)$fatal(1,"must keep forward arc t=%0d",i*20);
    if(status[23:16]==0 || status[15:8]==0)$fatal(1,"pivot/zero duty t=%0d",i*20);
   end
   if(i==119 && !stby)$fatal(1,"PL stopped before 1200ms source loss");
   if(i>=120 && i<130 && (stby||pwm_a||pwm_b))$fatal(1,"1200ms silence failed to stop");
   if(i>=132 && !stby)$fatal(1,"source return failed to resume");
  end
  $display("PASS: actual PS command trace through unchanged PL: forward arc, no early 300ms stop, 1200ms loss stop and automatic recovery");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
