`timescale 1ns/1ps
// Real SoC top + serial microphone model. PS wrapper is a simulation-only
// control/AXIS sink stub, NOT a model of DDR, AXI DMA or the ARM processor.
module tb_mic_soc_stream;
 reg clk=0;always #5 clk=~clk;
 wire bclk,ws,power_en,pan_pwm,tilt_pwm;
 localparam [31:0] SERVO_CONTROL=(32'd1500<<1)|(32'd1600<<13)|(32'd3<<25);
 integer servo_edges=0;
 always @(posedge pan_pwm) servo_edges=servo_edges+1;
 wire [3:0] data;
 wire [167:0] expected;
 wire [7:0] epoch=0;
 integer model_frame,slot_bit;
 mic_soc_top dut(.sys_clk_p(clk),.sys_clk_n(~clk),.mic_data(data),
  .mic_bclk(bclk),.mic_ws(ws),.fep_power_en(power_en),.servo_pan_pwm(pan_pwm),.servo_tilt_pwm(tilt_pwm));
 defparam dut.guard.STARTUP_CYCLES=10;
 i2s_mic_array_model model(.resetn(dut.capture_resetn),.bclk(bclk),.ws(ws),
  .epoch(epoch),.data(data),.expected_samples(expected),.frame_id(model_frame),.slot_bit(slot_bit));
 reg [167:0] expected_queue[0:2047];
 integer queued=0,words=0,edges=0,old_edges,blocks=0;
 reg collecting=0;
 reg [31:0] expected_word;
 reg [15:0] random_state=16'h1234;
 always @(negedge clk) begin
  random_state={random_state[14:0],random_state[15]^random_state[13]^random_state[12]^random_state[10]};
  dut.system_i.test_ready=random_state[0] | random_state[1];
 end
 always @(posedge bclk) edges=edges+1;
 always @(posedge clk) if(collecting) begin
  if(dut.frame_valid && dut.busy && dut.packet.frames_taken<2048) begin
   if(queued>=2048) $fatal(1,"too many input frames");
   expected_queue[queued]=expected;queued=queued+1;
  end
  if(dut.tvalid && dut.tready) begin
   if(words/8>=queued) $fatal(1,"output without input");
   if(words%8==0) expected_word=words/8;
   else expected_word=$signed(expected_queue[words/8][(words%8-1)*24 +:24]);
   if(dut.tdata !== expected_word) $fatal(1,"word %0d got %h expected %h",words,dut.tdata,expected_word);
   if(dut.tkeep !== 4'hf || dut.tlast !== (words==16383)) $fatal(1,"keep/TLAST mismatch");
   words=words+1;
  end
 end
 initial begin
  repeat(20) @(negedge clk);
  dut.system_i.test_resetn=1;
  wait(dut.capture_resetn);repeat(8000) @(negedge clk);
  repeat(2) begin
   words=0;queued=0;collecting=1;dut.system_i.test_control=SERVO_CONTROL|1;
   wait(dut.done);@(negedge clk);
   if(words!=16384 || queued!=2048 || (dut.status & 32'h1f)!==32'h2) $fatal(1,"bad completed block");
   dut.system_i.test_control=SERVO_CONTROL;collecting=0;blocks=blocks+1;
   old_edges=edges;repeat(8000) @(negedge clk);
   if(edges-old_edges<240 || !power_en || !dut.capture_resetn) $fatal(1,"microphone clock/power stopped between blocks");
  end
  if(dut.status[16:5]!==12'd1500 || dut.status[28:17]!==12'd1600)$fatal(1,"12-bit status mapping");
  if(servo_edges<3 || dut.servo_fault) $fatal(1,"servo did not coexist with two capture blocks");
  dut.system_i.test_control=0;repeat(2)@(negedge clk);
  if(pan_pwm || tilt_pwm)$fatal(1,"servo disable after capture");
  $display("PASS: concurrent two-axis PWM and real SoC top, 2 x 2048 serial frames, seven signed channels, random AXIS stalls, sequence/TLAST, continuous microphone clocks between blocks");
  $finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
