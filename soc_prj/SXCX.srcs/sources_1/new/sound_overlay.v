`timescale 1ns/1ps
// Direction annotation, not an acoustic power image. 1280x720 raster.
// SOS: 204x84px (25% smaller). Only the bottom-right direction plot remains.
// All layers and HDMI sync have the same three-register latency.
module sound_overlay(
 input wire clk,resetn,input wire [23:0] rgb_in,input wire de_in,hs_in,vs_in,
 input wire [10:0] x,input wire [9:0] y,
 input wire valid,input wire [10:0] center_x,input wire [9:0] center_y,
 input wire direction_valid,input wire signed [7:0] az,el,
 output reg [23:0] rgb_out,output reg de_out,hs_out,vs_out);
 function [34:0] glyph(input [7:0] ascii);
 begin case(ascii)
   8'd69:glyph=35'b11111100001000011110100001000011111;
   8'd83:glyph=35'b01111100001000001110000010000111110;
   8'd79:glyph=35'b01110100011000110001100011000101110;
   8'd82:glyph=35'b11110100011000111110101001001010001;
   8'd67:glyph=35'b01111100001000010000100001000001111;
   8'd85:glyph=35'b10001100011000110001100011000101110;
   8'd78:glyph=35'b10001110011100110101100111001110001;
   default:glyph=0;
 endcase end
 endfunction
 function sos_bit(input signed [12:0] px,py);
 reg [4:0] col;reg [2:0] row,letter_col;reg [34:0] pattern;
 begin
  sos_bit=0;
  if(px>=0 && px<204 && py>=0 && py<84)begin
   col=px[7:0]/8'd12;row=py[6:0]/7'd12;
   if(col<5)begin pattern=glyph("S");letter_col=col;end
   else if(col>=6 && col<11)begin pattern=glyph("O");letter_col=col-6;end
   else if(col>=12)begin pattern=glyph("S");letter_col=col-12;end
   else begin pattern=0;letter_col=0;end
   sos_bit=pattern[34-row*5-letter_col];
  end
 end
 endfunction
 wire signed [12:0] sx=$signed({2'b0,x})-$signed({2'b0,center_x})+13'sd102;
 wire signed [11:0] sy=$signed({2'b0,y})-$signed({2'b0,center_y})+12'sd42;
 wire signed [11:0] dot_x=12'sd1120+($signed(az)*12'sd3)/12'sd2;
 wire signed [11:0] dot_y=12'sd608-($signed(el)*12'sd5)/12'sd4;
 wire signed [11:0] dx=$signed({1'b0,x})-dot_x,dy=$signed({2'b0,y})-dot_y;
 wire signed [11:0] bx=$signed({1'b0,x})-12'sd1120,by=$signed({2'b0,y})-12'sd608;
 wire map_panel=x>=976 && x<1264 && y>=480 && y<704;
 wire plot=x>=992 && x<1248 && y>=520 && y<688;
 reg [7:0] character;reg text_on;reg [2:0] font_row,font_col;
 reg [23:0] text_color;integer column;
 reg [111:0] title;
 always @* begin
  character=" ";text_on=0;font_row=0;font_col=0;text_color=24'hf1f5f9;
  column=0;title=0;
  if(x>=992 && x<1232)begin
   column=(x-992)>>4;font_col=((x-992)&15)>>1;
   if(y>=488 && y<502)begin
    title=direction_valid?"SOURCE        ":"NO SOURCE     ";font_row=(y-488)>>1;
    if(column<14)character=title[(13-column)*8+:8];
    text_on=font_col<5;text_color=24'h8ed8ff;
   end
  end
 end
 reg [23:0] rgb1,rgb2,color1;reg [34:0] glyph1;
 reg [2:0] row1,col1;reg text1,sos1,shadow1,map1,plot1,border1,grid1,dot1;
 reg [23:0] red_distance1,blue_distance1;
 reg de1,hs1,vs1,de2,hs2,vs2;reg [23:0] composite;
 always @* begin
  composite=rgb1;
  if(shadow1)composite=24'h101010;
  if(sos1)composite=24'hff3030;
  if(map1)composite=24'h142333;
  if(plot1)begin
   composite=grid1?24'hb2c4d0:24'he9f0f5;
   if(blue_distance1<=576)composite=24'h207db5;
   if(dot1 && red_distance1<=25)composite=24'hff2525;
  end
  if(border1)composite=24'h63849c;
  if(text1 && glyph1[34-row1*5-col1])composite=color1;
 end
 always @(posedge clk)begin
  if(!resetn)begin
   rgb1<=0;rgb2<=0;rgb_out<=0;color1<=0;glyph1<=0;row1<=0;col1<=0;
   text1<=0;sos1<=0;shadow1<=0;map1<=0;plot1<=0;border1<=0;grid1<=0;dot1<=0;
   red_distance1<=0;blue_distance1<=0;
   de1<=0;hs1<=0;vs1<=0;de2<=0;hs2<=0;vs2<=0;de_out<=0;hs_out<=0;vs_out<=0;
  end else begin
   rgb1<=rgb_in;de1<=de_in;hs1<=hs_in;vs1<=vs_in;
   sos1<=de_in && valid && y>=4 && sos_bit(sx,sy);
   shadow1<=de_in && valid && y>=4 && sos_bit(sx-3,sy-3);
   map1<=de_in && map_panel;plot1<=de_in && plot;
   border1<=de_in && map_panel && (x==976 || x==1263 || y==480 || y==703);
   grid1<=x==1120 || y==608;dot1<=direction_valid;
   red_distance1<=dx*dx+dy*dy;blue_distance1<=bx*bx+by*by;
   text1<=de_in && text_on;glyph1<=glyph(character);row1<=font_row;col1<=font_col;color1<=text_color;
   rgb2<=composite;de2<=de1;hs2<=hs1;vs2<=vs1;
   rgb_out<=rgb2;de_out<=de2;hs_out<=hs2;vs_out<=vs2;
  end
 end
endmodule
