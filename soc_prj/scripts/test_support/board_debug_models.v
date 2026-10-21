`timescale 1ns / 1ps
// Standalone RTL-test models only. Never add this file to the hardware project.
// No analog behavior or actual ILA/VIO JTAG implementation is simulated here.
module IBUFDS #(parameter DIFF_TERM="FALSE", parameter IBUF_LOW_PWR="FALSE")
    (input I, input IB, output O);
    assign O = I;
endmodule
module BUFG(input I, output O);
    assign O = I;
endmodule
module vio_mic_control(input clk, input probe_in0, input probe_in1,
    input [31:0] probe_in2, output reg probe_out0 = 0);
endmodule
module ila_mic_raw(input clk, input [3:0] probe0, input probe1,
    input probe2, input probe3, input probe4);
endmodule
module ila_mic_samples(input clk, input probe0,
    input [23:0] probe1, probe2, probe3, probe4, probe5, probe6, probe7,
    input [31:0] probe8, input probe9);
endmodule
