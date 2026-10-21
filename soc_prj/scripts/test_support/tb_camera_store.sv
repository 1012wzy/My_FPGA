`timescale 1ns/1ps
module tb_camera_store;
 reg pc=0,dc=0;always #7 pc=~pc;always #11 dc=~dc;
 reg rst=0,vs=0,href=0,swap=0;reg [7:0] data=0;reg [18:0] addr=0;
 wire [15:0] pixel;wire avail,bad,toggle;wire [5:0] inf,good,shown;wire [2:0] errors;
 camera_frame_store #(.W(4),.H(2)) dut(pc,rst,vs,href,data,dc,rst,swap,addr,pixel,avail,bad,toggle,inf,good,shown,errors);
 task tick(input bit v,input bit h,input [7:0] b);
 @(negedge pc);vs=v;href=h;data=b;
 endtask
 task frame(input integer base,input bit broken);
 tick(1,0,0);tick(1,0,0);tick(0,0,0);
 for(integer y=0;y<2;y++)begin
  for(integer x=0;x<4;x++)begin
   tick(0,1,(base+y*4+x)>>8);
   if(!(broken && y==1 && x==3))tick(0,1,base+y*4+x);
  end
  tick(0,0,0);tick(0,0,0);
 end
 tick(1,0,0);tick(1,0,0);
 endtask
 task publish;
 repeat(12)@(negedge dc);swap=1;repeat(2)@(negedge dc);swap=0;
 repeat(18)@(negedge pc);
 endtask
 task check(input integer base);
 for(integer i=0;i<8;i++)begin
  @(negedge dc);addr=i;@(posedge dc);#1;
  if(pixel!==base+i)$fatal(1,"pixel %0d expected %h got %h",i,base+i,pixel);
 end
 endtask
 // Assertion independent of request timing: live and queued banks are immutable.
 always @(posedge pc)if(rst && dut.store)begin
  if(dut.write_bank==dut.read_bank)$fatal(1,"writer touched live reader bank");
  if(dut.busy && dut.write_bank==dut.queued_bank)$fatal(1,"writer touched queued bank");
 end
 integer before_good,before_shown;
 initial begin
  repeat(4)@(negedge pc);rst=1;
  frame(16'h1200,0);repeat(6)@(negedge dc);
  if(avail)$fatal(1,"bank changed outside vblank");
  publish();if(!avail||bad)$fatal(1,"complete frame not published");check(16'h1200);
  frame(16'h2300,0);check(16'h1200);
  before_good=good;
  frame(16'h9900,0);check(16'h1200);
  if(good!=((before_good+1)&63))$fatal(1,"third bank did not capture while prior frame queued");
  publish();check(16'h2300);
  frame(16'h3400,1);publish();if(!bad||!errors[1])$fatal(1,"odd-byte frame undetected");check(16'h2300);
  frame(16'h4500,0);publish();check(16'h4500);
  // Simulate the old failure window: previous frame is queued at next VS fall,
  // but reader ACK arrives during that new frame. It must still be captured.
  frame(16'h5600,0);
  fork
   frame(16'h6700,0);
   begin repeat(7)@(negedge dc);swap=1;repeat(2)@(negedge dc);swap=0;end
  join
  publish();check(16'h6700);
  // Long run through 6-bit counter wrap, verifying every frame and bank reuse.
  before_good=good;before_shown=shown;
  for(integer k=0;k<70;k++)begin frame(16'h1000+k*16,0);publish();check(16'h1000+k*16);end
  if(good!=((before_good+70)&63)||shown!=((before_shown+70)&63))$fatal(1,"frame counters wrapped incorrectly");
  $display("PASS: triple bank ownership, capture while queued, late ACK without frame skip, malformed recovery, 70-frame wrap and pixel integrity");$finish;
 end
 initial begin #300000;$fatal(1,"timeout");end
endmodule
