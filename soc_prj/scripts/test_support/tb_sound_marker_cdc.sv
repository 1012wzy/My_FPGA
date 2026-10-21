`timescale 1ns/1ps
module tb_sound_marker_cdc;
 reg sc=0,pc=0,rst=0,blank=0;always #5 sc=~sc;always #7 pc=~pc;
 reg [31:0] control=0;wire ack,valid;wire [10:0] x;wire [9:0] y;
 sound_marker_cdc #(.STALE_FRAMES(12)) dut(sc,control,ack,pc,rst,blank,valid,x,y);
 task send(input bit v,input integer xx,yy);
  @(negedge sc);control=(1<<31)|(v<<30)|(xx<<19)|(yy<<9);
  wait(ack);@(negedge sc);control[31]=0;wait(!ack);repeat(8)@(negedge pc);
 endtask
 task frame;@(negedge pc);blank=1;@(negedge pc);blank=0;endtask
 integer previous_x,previous_y;
 initial begin
  #300;rst=1;send(1,1279,719);
  if(valid)$fatal(1,"changed mid-frame");frame();
  if(!valid||x!=1279||y!=719)$fatal(1,"initial acquisition width/atomicity");
  send(1,0,0);if(x!=1279||y!=719)$fatal(1,"mid-frame movement");
  frame();if(x!=639||y!=359||!valid)$fatal(1,"first half step");
  repeat(10)begin
   previous_x=x;previous_y=y;frame();
   if(x>previous_x||y>previous_y||!valid)$fatal(1,"nonmonotonic/overshoot");
  end
  if(x!=0||y!=0)$fatal(1,"no exact convergence");
  frame();if(!valid)$fatal(1,"early expiry");frame();if(valid)$fatal(1,"stale marker not hidden");
  send(1,640,360);frame();if(!valid||x!=640||y!=360)$fatal(1,"reacquire must snap");
  send(1,700,400);frame();if(x!=670||y!=380)$fatal(1,"positive half step");
  send(0,700,400);frame();if(valid)$fatal(1,"explicit invalid must hide immediately");
  send(1,1500,900);frame();if(valid)$fatal(1,"offscreen input");
  $display("PASS: acknowledged 22-bit crossing, vblank interpolation, monotonic no overshoot, exact convergence, initial snap, expiry, invalid and offscreen");$finish;
 end
 initial begin #100000;$fatal(1,"CDC timeout");end
endmodule
