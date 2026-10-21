`timescale 1ns/1ps
module motor_test_top(
 input wire sys_clk_p,sys_clk_n,mode_key_n,
 output wire motor_pwm_a,motor_ain1,motor_ain2,motor_pwm_b,motor_bin1,motor_bin2,motor_stby,
 output wire mode_led,drive_led,fep_power_en,servo_pan_pwm,servo_tilt_pwm
);
 wire clk_in,clk;wire [2:0] phase;
 IBUFDS #(.DIFF_TERM("FALSE"),.IBUF_LOW_PWR("FALSE")) ib(.I(sys_clk_p),.IB(sys_clk_n),.O(clk_in));
 BUFG bu(.I(clk_in),.O(clk));
 // FPGA configuration initializes reset; release after 100ms supply settling.
 reg [23:0] startup_count=0;
 reg resetn=0;
 always @(posedge clk)if(!resetn)begin
  if(startup_count==9999999)resetn<=1;
  else startup_count<=startup_count+1;
 end
 assign fep_power_en=1'b1;
 assign servo_pan_pwm=1'b0;
 assign servo_tilt_pwm=1'b0;
 motor_cycle #(.DUTY_PERCENT(25),.LEFT_FORWARD(1'b1),.RIGHT_FORWARD(1'b1)) motor(
 .clk(clk),.resetn(resetn),.key_n(mode_key_n),.phase(phase),
 .pwm_a(motor_pwm_a),.ain1(motor_ain1),.ain2(motor_ain2),
 .pwm_b(motor_pwm_b),.bin1(motor_bin1),.bin2(motor_bin2),.stby(motor_stby),
 .running_led(mode_led),.reverse_led(drive_led));
endmodule
