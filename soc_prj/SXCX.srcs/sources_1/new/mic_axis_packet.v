`timescale 1ns/1ps
// One commanded block = FRAMES records; each record = sequence + 7 signed samples.
// Synchronous to native 100MHz; no clock crossing. Backpressure overflow is fatal
// for this block and is reported, never silently treated as continuous audio.
module mic_axis_packet #(parameter FRAMES=2048)(
 input wire clk, resetn, enable, frame_valid,
 input wire [167:0] samples,
 output wire [31:0] m_axis_tdata,
 output wire [3:0] m_axis_tkeep,
 output wire m_axis_tvalid, m_axis_tlast,
 input wire m_axis_tready,
 output reg busy, done, overflow
);
 reg [255:0] record;
 reg pending;
 reg [2:0] word_index;
 reg [31:0] frames_taken;
 reg armed;
 wire last_word = word_index==7;
 assign m_axis_tvalid=pending;
 assign m_axis_tkeep=4'hf;
 assign m_axis_tdata=record[word_index*32 +:32];
 assign m_axis_tlast=pending && last_word && frames_taken==FRAMES;
 integer k;
 always @(posedge clk) begin
  if(!resetn || !enable) begin
   busy<=0;done<=0;overflow<=0;pending<=0;word_index<=0;
   frames_taken<=0;armed<=1;record<=0;
  end else begin
   if(armed) begin busy<=1;armed<=0;end
   if(pending && m_axis_tready) begin
    if(last_word) begin
     pending<=0;word_index<=0;
     if(frames_taken==FRAMES) begin busy<=0;done<=1;end
    end else word_index<=word_index+1'b1;
   end
   if(busy && frame_valid && frames_taken<FRAMES) begin
    if(pending && !(m_axis_tready && last_word)) overflow<=1;
    else begin
     record[31:0]<=frames_taken;
     for(k=0;k<7;k=k+1)
      record[(k+1)*32 +:32]<={{8{samples[k*24+23]}},samples[k*24 +:24]};
     frames_taken<=frames_taken+1;
     pending<=1;word_index<=0;
    end
   end
  end
 end
endmodule
