`timescale 1ns/1ps
// Whole coordinate words cross with an acknowledged XPM handshake.
// Update only in vertical blank; expire if the PS stops refreshing coordinates.
module sound_marker_cdc #(parameter STALE_FRAMES=30)(
 input wire src_clk,input wire [31:0] control,output wire ack,
 input wire pixel_clk,resetn,frame_blank,output wire valid,
 output wire [10:0] center_x,output wire [9:0] center_y);
 wire [21:0] received;wire received_strobe;
 xpm_cdc_handshake #(.WIDTH(22),.DEST_EXT_HSK(0),.SRC_SYNC_FF(2),
 .DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.SIM_ASSERT_CHK(1))
 transfer(.src_clk(src_clk),.src_in(control[30:9]),.src_send(control[31]),.src_rcv(ack),
 .dest_clk(pixel_clk),.dest_out(received),.dest_req(received_strobe),.dest_ack(1'b0));
 // Half-error interpolation at 60Hz, never extrapolating beyond a valid target.
 function [10:0] approach(input [10:0] current_value,target);
 begin
  if(target>=current_value)approach=current_value+((target-current_value+11'd1)>>1);
  else approach=current_value-((current_value-target+11'd1)>>1);
 end
 endfunction
 reg [10:0] shown_x;reg [9:0] shown_y;
 reg [21:0] pending,active;reg pending_valid;reg [5:0] age;
 wire [21:0] incoming=received_strobe?received:pending;
 wire incoming_valid=incoming[21] && incoming[20:10]<1280 && incoming[9:0]<720;
 always @(posedge pixel_clk)begin
  if(!resetn)begin shown_x<=0;shown_y<=0;pending<=0;active<=0;pending_valid<=0;age<=STALE_FRAMES;end
  else begin
   if(received_strobe)begin pending<=received;pending_valid<=1;end
   if(frame_blank)begin
    if(received_strobe || pending_valid)begin
     active<=incoming;pending_valid<=0;age<=0;
     if(incoming_valid)begin
      shown_x<=valid?approach(shown_x,incoming[20:10]):incoming[20:10];
      shown_y<=valid?approach({1'b0,shown_y},{1'b0,incoming[9:0]}):incoming[9:0];
     end
    end else if(age<STALE_FRAMES)begin
     age<=age+1'b1;if(age==STALE_FRAMES-1)active[21]<=0;
     if(valid)begin
      shown_x<=approach(shown_x,active[20:10]);
      shown_y<=approach({1'b0,shown_y},{1'b0,active[9:0]});
     end
    end
   end
  end
 end
 assign valid=active[21] && active[20:10]<1280 && active[9:0]<720;
 assign center_x=shown_x;assign center_y=shown_y;
endmodule

