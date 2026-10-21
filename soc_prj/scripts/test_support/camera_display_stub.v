`timescale 1ns/1ps
// AUDIO TESTS ONLY. Never included in hardware build.
module camera_display(input clk,resetn,input [31:0] direction_control,input [31:0] control,output [31:0] status,
 input camera_pclk,camera_vsync,camera_href,input [7:0] camera_data,
 output camera_xclk,inout camera_scl,camera_sda,output hdmi_clk_p,hdmi_clk_n,
 output [2:0] hdmi_d_p,hdmi_d_n);
 assign status=0;assign camera_xclk=0;assign hdmi_clk_p=0;assign hdmi_clk_n=1;
 assign hdmi_d_p=0;assign hdmi_d_n=7;
endmodule
