`timescale 1ns/1ps
module dvi_serialize(input wire pixel_clk,serial_clk,reset,input wire [9:0] symbol,output wire serial);
 wire cascade1,cascade2;
 OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_RATE_TQ("SDR"),.DATA_WIDTH(10),.SERDES_MODE("MASTER"),.TRISTATE_WIDTH(1)) master(
 .CLK(serial_clk),.CLKDIV(pixel_clk),.RST(reset),.OCE(1'b1),.OQ(serial),
 .D1(symbol[0]),.D2(symbol[1]),.D3(symbol[2]),.D4(symbol[3]),
 .D5(symbol[4]),.D6(symbol[5]),.D7(symbol[6]),.D8(symbol[7]),
 .SHIFTIN1(cascade1),.SHIFTIN2(cascade2),.SHIFTOUT1(),.SHIFTOUT2(),
 .T1(1'b0),.T2(1'b0),.T3(1'b0),.T4(1'b0),.TCE(1'b0),.TBYTEIN(1'b0),.TBYTEOUT(),.TQ(),.TFB(),.OFB());
 OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_RATE_TQ("SDR"),.DATA_WIDTH(10),.SERDES_MODE("SLAVE"),.TRISTATE_WIDTH(1)) slave(
 .CLK(serial_clk),.CLKDIV(pixel_clk),.RST(reset),.OCE(1'b1),.OQ(),
 .D1(1'b0),.D2(1'b0),.D3(symbol[8]),.D4(symbol[9]),.D5(1'b0),.D6(1'b0),.D7(1'b0),.D8(1'b0),
 .SHIFTIN1(1'b0),.SHIFTIN2(1'b0),.SHIFTOUT1(cascade1),.SHIFTOUT2(cascade2),
 .T1(1'b0),.T2(1'b0),.T3(1'b0),.T4(1'b0),.TCE(1'b0),.TBYTEIN(1'b0),.TBYTEOUT(),.TQ(),.TFB(),.OFB());
endmodule
