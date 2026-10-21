`timescale 1ns/1ps
module tb_dvi_encode;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,de=0;reg [7:0] data=0;reg [1:0] control=0;
 wire [9:0] symbol;
 dvi_encode dut(clk,rst,de,data,control,symbol);
 function [7:0] decode(input [9:0] s);
 reg [7:0] q,d;
 begin
  q=s[9]?~s[7:0]:s[7:0];d[0]=q[0];
  for(integer j=1;j<8;j++)d[j]=s[8]?(q[j]^q[j-1]):~(q[j]^q[j-1]);
  decode=d;
 end endfunction
 integer sum=0,ones;reg [9:0] expected;
 initial begin
  repeat(3)@(negedge clk);rst=1;
  for(integer c=0;c<4;c++)begin
   control=c;@(posedge clk);#1;
   case(c)0:expected=10'b1101010100;1:expected=10'b0010101011;2:expected=10'b0101010100;3:expected=10'b1010101011;endcase
   if(symbol!==expected)$fatal(1,"control symbol");@(negedge clk);
  end
  for(integer n=0;n<8192;n++)begin
   de=1;data=n<256?n:$random;@(posedge clk);#1;
   if(decode(symbol)!==data)$fatal(1,"TMDS decode");
   ones=0;for(integer j=0;j<10;j++)ones+=symbol[j];
   sum+=2*ones-10;
   if(sum>8||sum< -8)$fatal(1,"unbounded disparity %0d",sum);
   @(negedge clk);
  end
  $display("PASS: all byte values, 8192 symbols decoded, four control symbols, bounded running disparity");$finish;
 end
endmodule
