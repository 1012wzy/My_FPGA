`timescale 1ns/1ps
// Rotate the installed camera by 180 degrees; use FLIP_X=0 for vertical-only.
module camera_display #(parameter FLIP_X=1, FLIP_Y=1, STALE_CYCLES=74250000)(
 input wire clk,resetn,input wire [31:0] direction_control,input wire [31:0] control,output wire [31:0] status,
 input wire camera_pclk,camera_vsync,camera_href,input wire [7:0] camera_data,
 output wire camera_xclk,inout wire camera_scl,camera_sda,
 output wire hdmi_clk_p,hdmi_clk_n,output wire [2:0] hdmi_d_p,hdmi_d_n);
 wire pixel_clk,serial_clk,xclk,display_locked,camera_locked;
 camera_display_clocks display_clock_ip(.clk_in1(clk),.reset(!resetn),
 .clk_out1(pixel_clk),.clk_out2(serial_clk),.locked(display_locked));
 camera_xclk_ip camera_clock_ip(.clk_in1(clk),.reset(!resetn),.clk_out1(xclk),.locked(camera_locked));
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) camera_clock_out(.C(xclk),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0),.Q(camera_xclk));
 assign camera_scl=control[0]?1'b0:1'bz;
 assign camera_sda=control[1]?1'b0:1'bz;
 (* ASYNC_REG="TRUE" *) reg [1:0] pixel_reset_sync,camera_reset_sync;
 always @(posedge pixel_clk or negedge resetn)
  if(!resetn)pixel_reset_sync<=0;else pixel_reset_sync<={pixel_reset_sync[0],display_locked};
 always @(posedge camera_pclk or negedge resetn)
  if(!resetn)camera_reset_sync<=0;else camera_reset_sync<={camera_reset_sync[0],control[2]};
 wire pixel_resetn=pixel_reset_sync[1];
 reg [10:0] h;reg [9:0] v;
 wire de=h<1280 && v<720;
 wire hs=h>=1390 && h<1430,vs=v>=725 && v<730;
 // 800x450 ->1280x720: exact 5/8 source-coordinate scale, aspect preserved.
 wire [12:0] hx5={2'b0,h}+({2'b0,h}<<2);
 wire [11:0] vy5={2'b0,v}+({2'b0,v}<<2);
 wire [9:0] sx=hx5[12:3],sy=vy5[11:3];
 wire [9:0] source_x=FLIP_X ? 10'd799-sx : sx;
 wire [9:0] source_y=FLIP_Y ? 10'd449-sy : sy;
 wire [18:0] row_base=({9'b0,source_y}<<9)+({9'b0,source_y}<<8)+({9'b0,source_y}<<5);
 wire [18:0] address=de ? row_base+{9'b0,source_x} : 19'd0;
 wire [15:0] rgb565;
 wire frame_available,malformed,frame_toggle;
 // Matched fabric registers keep data/HREF/VSYNC on the same PCLK cycle.
 // AF28 uses non-dedicated clock routing; avoid fixed ILOGIC ZHOLD delay.
 (* IOB="FALSE" *) reg [7:0] dvp_data;
 (* IOB="FALSE" *) reg dvp_vsync,dvp_href;
 always @(posedge camera_pclk)begin dvp_data<=camera_data;dvp_vsync<=camera_vsync;dvp_href<=camera_href;end
 wire [5:0] input_frames,complete_frames,display_frames;
 wire [2:0] error_flags;
 camera_frame_store store(.camera_pclk(camera_pclk),.write_resetn(camera_reset_sync[1]),
 .camera_vsync(dvp_vsync),.camera_href(dvp_href),.camera_data(dvp_data),
 .pixel_clk(pixel_clk),.read_resetn(pixel_resetn),.swap_allowed(h==0 && v==720),
 .read_index(address),.pixel(rgb565),.frame_available(frame_available),
 .malformed(malformed),.frame_toggle(frame_toggle),.input_frames(input_frames),
 .complete_frames(complete_frames),.display_frames(display_frames),.error_flags(error_flags));
 reg de_d,hs_d,vs_d;reg [10:0] x_d;reg [9:0] y_d;
 always @(posedge pixel_clk)begin
  if(!pixel_resetn)begin h<=0;v<=0;de_d<=0;hs_d<=1;vs_d<=1;x_d<=0;y_d<=0;end
  else begin
   if(h==1649)begin h<=0;if(v==749)v<=0;else v<=v+1'b1;end else h<=h+1'b1;
   de_d<=de;hs_d<=hs;vs_d<=vs;x_d<=h;y_d<=v;
  end
 end
 reg previous_frame;reg [26:0] frame_age;
 always @(posedge pixel_clk)begin
  if(!pixel_resetn)begin previous_frame<=0;frame_age<=0;end
  else begin
   previous_frame<=frame_toggle;
   if(!frame_available || frame_toggle!=previous_frame)frame_age<=0;
   else if(frame_age<STALE_CYCLES)frame_age<=frame_age+1'b1;
  end
 end
 wire image_fresh=frame_available && frame_age<STALE_CYCLES;
 wire [23:0] video_rgb=frame_available ? {rgb565[15:11],rgb565[15:13],rgb565[10:5],rgb565[10:9],rgb565[4:0],rgb565[4:2]} : 24'b0;
 wire [23:0] rgb=y_d<4 ? (image_fresh?24'h00ff00:(frame_available?24'hffb000:24'hff0000)) : video_rgb;
 wire marker_valid,marker_ack;wire [10:0] center_x;wire [9:0] center_y;
 sound_marker_cdc marker(.src_clk(clk),.control(control),.ack(marker_ack),
 .pixel_clk(pixel_clk),.resetn(pixel_resetn),.frame_blank(h==0 && v==720),
 .valid(marker_valid),.center_x(center_x),.center_y(center_y));
 wire direction_valid;wire signed [7:0] direction_az,direction_el;
 sound_direction_cdc direction(.src_clk(clk),.src_resetn(resetn),.control(direction_control),
 .pixel_clk(pixel_clk),.resetn(pixel_resetn),.frame_blank(h==0 && v==720),
 .valid(direction_valid),.az(direction_az),.el(direction_el));
 wire [23:0] overlay_rgb;wire overlay_de,overlay_hs,overlay_vs;
 sound_overlay overlay(.clk(pixel_clk),.resetn(pixel_resetn),.rgb_in(rgb),
 .de_in(de_d),.hs_in(hs_d),.vs_in(vs_d),.x(x_d),.y(y_d),
 .valid(marker_valid && image_fresh),.center_x(center_x),.center_y(center_y),
 .direction_valid(direction_valid && image_fresh),.az(direction_az),.el(direction_el),
 .rgb_out(overlay_rgb),.de_out(overlay_de),.hs_out(overlay_hs),.vs_out(overlay_vs));
 wire [9:0] b_symbol,g_symbol,r_symbol;
 dvi_encode eb(.clk(pixel_clk),.resetn(pixel_resetn),.de(overlay_de),.data(overlay_rgb[7:0]),.control({overlay_vs,overlay_hs}),.symbol(b_symbol));
 dvi_encode eg(.clk(pixel_clk),.resetn(pixel_resetn),.de(overlay_de),.data(overlay_rgb[15:8]),.control(2'b0),.symbol(g_symbol));
 dvi_encode er(.clk(pixel_clk),.resetn(pixel_resetn),.de(overlay_de),.data(overlay_rgb[23:16]),.control(2'b0),.symbol(r_symbol));
 wire [2:0] serial;
 dvi_serialize sb(.pixel_clk(pixel_clk),.serial_clk(serial_clk),.reset(!pixel_resetn),.symbol(b_symbol),.serial(serial[0]));
 dvi_serialize sg(.pixel_clk(pixel_clk),.serial_clk(serial_clk),.reset(!pixel_resetn),.symbol(g_symbol),.serial(serial[1]));
 dvi_serialize sr(.pixel_clk(pixel_clk),.serial_clk(serial_clk),.reset(!pixel_resetn),.symbol(r_symbol),.serial(serial[2]));
 OBUFDS blue(.I(serial[0]),.O(hdmi_d_p[0]),.OB(hdmi_d_n[0]));
 // Screenshot labels green P=T25,N=T24; physical P=T24,N=T25.
 OBUFDS green(.I(serial[1]),.O(hdmi_d_n[1]),.OB(hdmi_d_p[1]));
 OBUFDS red(.I(serial[2]),.O(hdmi_d_p[2]),.OB(hdmi_d_n[2]));
 wire clock_serial;
 ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) hdmi_clock_out(.C(pixel_clk),.CE(1'b1),
 .D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0),.Q(clock_serial));
 OBUFDS clock_buffer(.I(clock_serial),.O(hdmi_clk_p),.OB(hdmi_clk_n));
 reg fresh_registered,marker_registered;
 always @(posedge pixel_clk)begin
  fresh_registered<=image_fresh;marker_registered<=marker_valid && image_fresh;
 end
 (* ASYNC_REG="TRUE" *) reg [8:0] status_meta,status_sync;
 always @(posedge clk)begin
  if(!resetn)begin status_meta<=0;status_sync<=0;end
  else begin
   status_meta<={fresh_registered,marker_registered,malformed,frame_toggle,frame_available,camera_locked,display_locked,camera_sda,camera_scl};
   status_sync<=status_meta;
  end
 end
 // bit 9 = currently fresh image; bit 10 = stale image after a previous frame.
 wire [5:0] input_sync,complete_sync,display_sync;wire [2:0] error_sync;
 xpm_cdc_gray #(.WIDTH(6),.DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.REG_OUTPUT(1)) ci(
 .src_clk(camera_pclk),.src_in_bin(input_frames),.dest_clk(clk),.dest_out_bin(input_sync));
 xpm_cdc_gray #(.WIDTH(6),.DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.REG_OUTPUT(1)) cc(
 .src_clk(camera_pclk),.src_in_bin(complete_frames),.dest_clk(clk),.dest_out_bin(complete_sync));
 xpm_cdc_gray #(.WIDTH(6),.DEST_SYNC_FF(2),.INIT_SYNC_FF(1),.REG_OUTPUT(1)) cd(
 .src_clk(pixel_clk),.src_in_bin(display_frames),.dest_clk(clk),.dest_out_bin(display_sync));
 xpm_cdc_array_single #(.WIDTH(3),.DEST_SYNC_FF(2),.SRC_INPUT_REG(0),.INIT_SYNC_FF(1)) ce(
 .src_clk(camera_pclk),.src_in(error_flags),.dest_clk(clk),.dest_out(error_sync));
 assign status={error_sync,complete_sync,input_sync,display_sync,(status_sync[4] && !status_sync[8]),status_sync[8:7],marker_ack,status_sync[6:0]};
endmodule
