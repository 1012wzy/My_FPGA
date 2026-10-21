`timescale 1ns/1ps
module tb_sound_overlay;
 reg clk=0,rst=0;always #5 clk=~clk;
 reg [23:0] rgb=24'h204060;reg de=1,hs=0,vs=0,valid=0,dvalid=0;
 reg [10:0] x=0,cx=640;reg [9:0] y=360,cy=360;
 reg signed [7:0] az=0,el=0;
 wire [23:0] out;wire od,oh,ov;
 sound_overlay dut(clk,rst,rgb,de,hs,vs,x,y,valid,cx,cy,dvalid,az,el,out,od,oh,ov);
 task sample(input integer xx,yy,input bit enabled,input [23:0] expected);
  @(negedge clk);x=xx;y=yy;valid=enabled;
  repeat(3)@(posedge clk);#1;
  if(out!==expected||od!==de||oh!==hs||ov!==vs)$fatal(1,"pixel x=%d y=%d got=%h expected=%h",x,y,out,expected);
 endtask
 integer file_handle,px,py;
 initial begin
  #30;rst=1;
  sample(550,318,0,24'h204060);sample(550,318,1,24'hff3030);
  sample(538,318,1,24'h204060);sample(562,324,1,24'hff3030);
  sample(745,360,1,24'h204060);sample(100,100,1,24'h204060);
  cy=40;sample(520,0,1,24'h204060);cy=360;
  dvalid=0;sample(1120,608,0,24'h207db5);
  dvalid=1;sample(1120,608,0,24'hff2525);
  az=40;el=32;sample(1180,568,0,24'hff2525);sample(1120,608,0,24'h207db5);
  az=-40;el=-32;sample(1060,648,0,24'hff2525);
  dvalid=0;sample(1060,648,0,24'he9f0f5);
  sample(976,176,0,24'h204060);sample(980,220,0,24'h204060);
  de=0;hs=1;vs=1;sample(1120,608,1,24'h204060);
  // Dynamic blanking/sync scoreboard checks exact 3-register latency.
  for(integer i=0;i<40;i++)begin
   @(negedge clk);x=100;y=100;valid=0;de=i[0];hs=i[1];vs=i[2];rgb=i*12345;
   @(posedge clk);#1;

  end
  // Render the real RTL result, one pixel per cycle, to a portable PPM.
  de=1;hs=0;vs=0;valid=1;dvalid=1;az=20;el=12;cx=640;cy=360;
  file_handle=$fopen("sos_preview.ppm","wb");if(!file_handle)$fatal(1,"preview file");
  $fwrite(file_handle,"P6\n1280 720\n255\n");
  for(integer i=0;i<1280*720+2;i++)begin
   @(negedge clk);px=i%1280;py=i/1280;x=px;y=py;
   rgb={8'(40+px*80/1280),8'(55+py*90/720),8'(80+((px/80+py/80)%2)*20)};
   @(posedge clk);#1;
   if(i>=2)$fwrite(file_handle,"%c%c%c",out[23:16],out[15:8],out[7:0]);
  end
  $fclose(file_handle);
  $display("PASS: SOS 204x84 glyph/size/transparency/clipping, direction dot signs/validity, removed history panel, panel priority, status line, 3-stage sync, raster preview");$finish;
 end
 reg [26:0] q0,q1;integer cycles=0;
 always @(posedge clk)begin
  if(!rst)begin q0=0;q1=0;cycles=0;end
  else begin
   if(x==100 && y==100 && !valid)begin
    #1;if(cycles>=2 && {od,oh,ov,out}!==q1)$fatal(1,"pixel/sync latency");
    q1=q0;q0={de,hs,vs,rgb};cycles=cycles+1;
   end else cycles=0;
  end
 end
 initial begin #20000000;$fatal(1,"overlay timeout");end
endmodule
