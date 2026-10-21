`timescale 1ns/1ps
// SIMULATION ONLY. Hardware uses generated MMCM IP.
module camera_display_clocks(input clk_in1,reset,output reg clk_out1=0,clk_out2=0,output locked);
 always #6.734 clk_out1=~clk_out1;
 always #1.3468 clk_out2=~clk_out2;
 assign locked=!reset;
endmodule
module camera_xclk_ip(input clk_in1,reset,output reg clk_out1=0,output locked);
 always #20.833 clk_out1=~clk_out1;
 assign locked=!reset;
endmodule
