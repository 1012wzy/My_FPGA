`timescale 1ns/1ps
// DVI-compatible TMDS, symbols are transmitted least significant bit first.
module dvi_encode(input wire clk,resetn,de,input wire [7:0] data,
 input wire [1:0] control,output reg [9:0] symbol);
 reg [8:0] q;
 integer ones,i,balance;
 reg signed [5:0] disparity;
 always @* begin
  ones=0;for(i=0;i<8;i=i+1)ones=ones+data[i];
  q[0]=data[0];q[8]=!((ones>4)||((ones==4)&&!data[0]));
  for(i=1;i<8;i=i+1)q[i]=q[8]?(q[i-1]^data[i]):~(q[i-1]^data[i]);
  balance=0;for(i=0;i<8;i=i+1)balance=balance+(q[i]?1:-1);
 end
 always @(posedge clk)begin
  if(!resetn)begin disparity<=0;symbol<=10'b1101010100;end
  else if(!de)begin
   disparity<=0;
   case(control)
    0:symbol<=10'b1101010100;1:symbol<=10'b0010101011;
    2:symbol<=10'b0101010100;3:symbol<=10'b1010101011;
   endcase
  end else if(disparity==0 || balance==0)begin
   symbol<={~q[8],q[8],q[8]?q[7:0]:~q[7:0]};
   disparity<=disparity+(q[8]?balance:-balance);
  end else if((disparity>0 && balance>0)||(disparity<0 && balance<0))begin
   symbol<={1'b1,q[8],~q[7:0]};disparity<=disparity+(q[8]?2:0)-balance;
  end else begin
   symbol<={1'b0,q[8],q[7:0]};disparity<=disparity-(q[8]?0:2)+balance;
  end
 end
endmodule
