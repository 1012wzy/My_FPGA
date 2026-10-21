`timescale 1ns/1ps
// PS packet: sequence[31], valid[30], reserved[29], signed AZ[28:21], EL[20:13].
// Independent of SCCB/SOS coordinates. Coordinates are committed in vertical blank.
module sound_direction_cdc #(parameter STALE_FRAMES=30)(
 input wire src_clk,src_resetn,input wire [31:0] control,
 input wire pixel_clk,resetn,frame_blank,
 output reg valid,output reg signed [7:0] az,el);
 reg seen,send_word;reg [16:0] source_word;wire acknowledged;
 reg [1:0] state;
 always @(posedge src_clk)begin
  if(!src_resetn)begin seen<=0;send_word<=0;source_word<=0;state<=0;end
  else case(state)
   0:if(control[31]!=seen)begin source_word<={control[30],control[28:13]};seen<=control[31];state<=1;end
   1:begin send_word<=1;state<=2;end
   2:if(acknowledged)begin send_word<=0;state<=3;end
   3:if(!acknowledged)state<=0;
  endcase
 end
 wire [16:0] received;wire strobe;
 xpm_cdc_handshake #(.WIDTH(17),.DEST_EXT_HSK(0),.SRC_SYNC_FF(2),
 .DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.SIM_ASSERT_CHK(1)) transfer(
 .src_clk(src_clk),.src_in(source_word),.src_send(send_word),.src_rcv(acknowledged),
 .dest_clk(pixel_clk),.dest_out(received),.dest_req(strobe),.dest_ack(1'b0));
 reg [16:0] pending;reg pending_valid;reg [5:0] age;
 wire [16:0] update_word=strobe?received:pending;
 wire signed [7:0] update_az=update_word[15:8],update_el=update_word[7:0];
 wire in_range=update_az>=-75 && update_az<=75 && update_el>=-60 && update_el<=60;
 always @(posedge pixel_clk)begin
  if(!resetn)begin
   pending<=0;pending_valid<=0;age<=STALE_FRAMES;valid<=0;az<=0;el<=0;
  end else begin
   if(strobe)begin pending<=received;pending_valid<=1;end
   if(frame_blank)begin
    if(strobe || pending_valid)begin
     pending_valid<=0;age<=0;valid<=update_word[16] && in_range;
     az<=update_az;el<=update_el;

    end else if(age<STALE_FRAMES)begin
     age<=age+1'b1;if(age==STALE_FRAMES-1)valid<=0;
    end
   end
  end
 end
endmodule
