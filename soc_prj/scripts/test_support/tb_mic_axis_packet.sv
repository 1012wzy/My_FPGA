`timescale 1ns/1ps
module tb_mic_axis_packet;
 reg clk=0;always #5 clk=~clk;
 reg resetn=0,enable=0,frame_valid=0,ready=0;
 reg [167:0] samples=0;
 wire [31:0] data;wire [3:0] keep;wire valid,last,busy,done,overflow;
 mic_axis_packet #(.FRAMES(8)) dut(.clk(clk),.resetn(resetn),.enable(enable),.frame_valid(frame_valid),
 .samples(samples),.m_axis_tdata(data),.m_axis_tkeep(keep),.m_axis_tvalid(valid),
 .m_axis_tlast(last),.m_axis_tready(ready),.busy(busy),.done(done),.overflow(overflow));
 integer received=0,mode=0,seed=47;
 reg stalled=0;reg [31:0] held;reg heldlast;
 always @(negedge clk) if(mode==0) ready=($random(seed)&3)!=0;
 always @(posedge clk) begin
  if(resetn && enable) begin
   if(stalled && (data!==held || last!==heldlast || !valid)) $fatal(1,"AXIS changed during stall");
   stalled=valid && !ready;held=data;heldlast=last;
   if(valid && ready && mode==0) begin
    if(keep!==15) $fatal(1,"TKEEP");
    if(received%8==0) begin
     if(data!==received/8) $fatal(1,"Sequence");
    end else if($signed(data)!== (-(received/8*100+received%8))) $fatal(1,"Sign extension/order");
    if(last !== (received==63)) $fatal(1,"TLAST");
    received=received+1;
   end
  end else stalled=0;
 end
 task frame(input integer f);
  @(negedge clk);
  for(integer k=0;k<7;k=k+1) samples[k*24+:24]=-(f*100+k+1);
  frame_valid=1;@(negedge clk);frame_valid=0;
 endtask
 initial begin
  repeat(3) @(negedge clk);resetn=1;enable=1;
  repeat(3) @(negedge clk);
  for(integer f=0;f<8;f=f+1) begin frame(f);repeat(40) @(negedge clk);end
  if(received!=64 || !done || busy || overflow) $fatal(1,"Block completion");
  frame(99);repeat(20) @(negedge clk);if(received!=64) $fatal(1,"Extra frame after done");
  enable=0;@(negedge clk);mode=1;ready=0;enable=1;
  repeat(3) @(negedge clk);frame(0);frame(1);@(negedge clk);
  if(!overflow) $fatal(1,"Missing overflow");
  enable=0;@(negedge clk);if(overflow || valid || done) $fatal(1,"Abort reset");
  received=0;mode=0;enable=1;repeat(3) @(negedge clk);
  for(integer f=0;f<8;f=f+1) begin frame(f);repeat(40) @(negedge clk);end
  if(received!=64 || !done || overflow) $fatal(1,"Rearm");
  $display("PASS: AXIS signed/channel order, sequence, stalls, TLAST, overflow, abort, rearm");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
