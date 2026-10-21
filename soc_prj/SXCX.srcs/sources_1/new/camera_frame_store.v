`timescale 1ns/1ps
// Triple banks: reader, queued complete frame and current capture never overlap.
// Bank ownership crosses only through a complete four-phase XPM handshake.
module camera_frame_store #(parameter W=800,H=450,N=W*H)(
 input wire camera_pclk,write_resetn,camera_vsync,camera_href,
 input wire [7:0] camera_data,
 input wire pixel_clk,read_resetn,swap_allowed,
 input wire [18:0] read_index,output reg [15:0] pixel,
 output reg frame_available,output reg malformed,output reg frame_toggle,
 output reg [5:0] input_frames,complete_frames,display_frames,
 output reg [2:0] error_flags);
 (* ram_style="block" *) reg [15:0] memory[0:3*N-1];
 reg send;wire received;
 reg [1:0] queued_bank,reader_owned,write_bank,read_bank;
 wire [1:0] incoming_bank;wire incoming;reg accept;
 xpm_cdc_handshake #(.WIDTH(2),.DEST_EXT_HSK(1),.SRC_SYNC_FF(2),
 .DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.SIM_ASSERT_CHK(1)) bank_mailbox(
 .src_clk(camera_pclk),.src_in(queued_bank),.src_send(send),.src_rcv(received),
 .dest_clk(pixel_clk),.dest_out(incoming_bank),.dest_req(incoming),.dest_ack(accept));
 wire busy=send || received;
 wire [1:0] free_bank=(reader_owned!=0 && (!busy || queued_bank!=0))?0:
                     (reader_owned!=1 && (!busy || queued_bank!=1))?1:2;
 reg previous_vs,previous_href,writing,half_pixel,bad;
 reg [7:0] high_byte;reg [18:0] count;
 reg [10:0] line_pixels,lines;
 wire store=writing && camera_href && !camera_vsync && half_pixel && count<N && line_pixels<W && lines<H;
 wire [20:0] write_base=write_bank==0?0:write_bank==1?N:2*N;
 wire [20:0] read_base=read_bank==0?0:read_bank==1?N:2*N;
 always @(posedge camera_pclk)
  if(store)memory[write_base+count]<={high_byte,camera_data};
 always @(posedge camera_pclk)begin
  if(!write_resetn)begin
   send<=0;queued_bank<=1;reader_owned<=0;write_bank<=1;
   previous_vs<=0;previous_href<=0;writing<=0;half_pixel<=0;
   count<=0;line_pixels<=0;lines<=0;high_byte<=0;bad<=0;malformed<=0;
   input_frames<=0;complete_frames<=0;error_flags<=0;
  end else begin
   if(send && received)begin send<=0;reader_owned<=queued_bank;end
   previous_vs<=camera_vsync;previous_href<=camera_href;
   if(camera_vsync && !previous_vs)begin
    input_frames<=input_frames+1'b1;
    if(writing)begin
     if(!bad && !half_pixel && count==N &&
        (lines==H || (previous_href && line_pixels==W && lines==H-1)))begin
      complete_frames<=complete_frames+1'b1;
      if(!busy)begin queued_bank<=write_bank;send<=1;end
      // Busy reader: discard this completed frame, never overwrite its queue.
     end else begin malformed<=1;error_flags[0]<=1;end
    end
    writing<=0;half_pixel<=0;
   end else if(!camera_vsync && previous_vs)begin
    // Third bank remains free even before the previous frame is displayed.
    writing<=1;write_bank<=free_bank;
    half_pixel<=0;count<=0;line_pixels<=0;lines<=0;bad<=0;
    // Support zero back-porch without silently discarding its first byte.
    if(camera_href)begin high_byte<=camera_data;half_pixel<=1;end
   end else if(writing && !camera_vsync)begin
    if(camera_href)begin
     if(!half_pixel)begin high_byte<=camera_data;half_pixel<=1;end
     else begin
      half_pixel<=0;
      if(count<N && line_pixels<W && lines<H)begin count<=count+1'b1;line_pixels<=line_pixels+1'b1;end
      else begin bad<=1;error_flags[2]<=1;end
     end
    end else if(previous_href)begin
     if(half_pixel)begin bad<=1;error_flags[1]<=1;end
     if(line_pixels!=W || lines>=H)begin bad<=1;error_flags[0]<=1;end
     half_pixel<=0;line_pixels<=0;
     if(lines<2047)lines<=lines+1'b1;
    end
   end
  end
 end
 always @(posedge pixel_clk)begin
  if(!read_resetn)begin read_bank<=0;accept<=0;frame_available<=0;frame_toggle<=0;display_frames<=0;end
  else begin
   if(!incoming)accept<=0;
   if(swap_allowed && incoming && !accept)begin
    read_bank<=incoming_bank;accept<=1;frame_available<=1;
    frame_toggle<=~frame_toggle;display_frames<=display_frames+1'b1;
   end
  end
 end
 always @(posedge pixel_clk)pixel<=memory[read_base+read_index];
endmodule
