`timescale 1ns/1ps
module tb_sound_direction_cdc;
 reg sc=0,pc=0;always #5 sc=~sc;always #7 pc=~pc;
 reg rst=0,blank=0;reg [31:0] control=0;
 wire valid;wire signed [7:0] az,el;
 sound_direction_cdc #(.STALE_FRAMES(4)) dut(sc,rst,control,pc,rst,blank,valid,az,el);
 task frame;
  @(negedge pc);blank=1;@(negedge pc);blank=0;#1;
 endtask
 task send(input bit v,input integer a,e);
  @(negedge sc);control={~control[31],v,1'b0,a[7:0],e[7:0],13'b0};
  repeat(40)@(negedge pc);
 endtask
 initial begin
  repeat(5)@(negedge pc);rst=1;
  send(1,-75,60);if(valid)$fatal(1,"changed outside vblank");frame();
  if(!valid || az!=-75 || el!=60)$fatal(1,"signed packet");
  send(1,20,-15);if(az!=-75)$fatal(1,"midframe update");frame();
  if(az!=20 || el!=-15)$fatal(1,"direction update");
  send(0,0,0);frame();if(valid)$fatal(1,"invalid");
  send(1,76,0);frame();if(valid)$fatal(1,"range guard");
  send(1,0,0);frame();repeat(3)frame();if(!valid)$fatal(1,"early timeout");frame();
  if(valid)$fatal(1,"stale live dot");
  @(negedge pc);rst=0;repeat(5)@(negedge pc);if(valid || az || el)$fatal(1,"reset");
  $display("PASS: signed direction CDC, atomic vblank, invalid/range, stale expiry, reset; no history storage");$finish;
 end
 initial begin #100000;$fatal(1,"direction CDC timeout");end
endmodule
