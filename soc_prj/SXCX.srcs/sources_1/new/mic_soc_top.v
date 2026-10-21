`timescale 1ns/1ps
module mic_soc_top(
 inout wire [14:0] DDR_addr, inout wire [2:0] DDR_ba,
 inout wire DDR_cas_n,DDR_ck_n,DDR_ck_p,DDR_cke,DDR_cs_n,
 inout wire [3:0] DDR_dm, inout wire [31:0] DDR_dq,
 inout wire [3:0] DDR_dqs_n,DDR_dqs_p,
 inout wire DDR_odt,DDR_ras_n,DDR_reset_n,DDR_we_n,
 inout wire FIXED_IO_ddr_vrn,FIXED_IO_ddr_vrp,
 inout wire [53:0] FIXED_IO_mio,
 inout wire FIXED_IO_ps_clk,FIXED_IO_ps_porb,FIXED_IO_ps_srstb,
 input wire sys_clk_p,sys_clk_n,input wire [3:0] mic_data,
 output wire mic_bclk,mic_ws,fep_power_en,servo_pan_pwm,servo_tilt_pwm,
 input wire camera_pclk,camera_vsync,camera_href,input wire [7:0] camera_data,
 output wire camera_xclk,inout wire camera_scl,camera_sda,
 input wire mode_key_n,
 output wire motor_pwm_a,motor_ain1,motor_ain2,motor_pwm_b,motor_bin1,motor_bin2,motor_stby,mode_led,drive_led,
 output wire hdmi_clk_p,hdmi_clk_n,output wire [2:0] hdmi_d_p,hdmi_d_n
);
 wire clk_in,clk,resetn,capture_resetn,startup_resetn;
 wire [31:0] control,status,tdata;
 wire [3:0] tkeep;
 wire tvalid,tlast,tready,frame_valid,sync_error,busy,done,overflow;
 wire signed [23:0] sample0,sample1,sample2,sample3,sample4,sample5,sample6;
 IBUFDS #(.DIFF_TERM("FALSE"),.IBUF_LOW_PWR("FALSE")) ib(.I(sys_clk_p),.IB(sys_clk_n),.O(clk_in));
 BUFG bu(.I(clk_in),.O(clk));
 assign fep_power_en=1'b1;
 mic_capture_control guard(.clk(clk),.capture_enable(resetn),.resetn(startup_resetn));
 assign capture_resetn=startup_resetn & resetn;
 mic_array_top array(.clk(clk),.resetn(capture_resetn),.mic_data(mic_data),
 .mic_bclk(mic_bclk),.mic_ws(mic_ws),.sample0(sample0),.sample1(sample1),
 .sample2(sample2),.sample3(sample3),.sample4(sample4),.sample5(sample5),
 .sample6(sample6),.frame_valid(frame_valid),.sync_error(sync_error));
 mic_axis_packet packet(.clk(clk),.resetn(resetn),.enable(control[0]),
 .frame_valid(frame_valid),.samples({sample6,sample5,sample4,sample3,sample2,sample1,sample0}),
 .m_axis_tdata(tdata),.m_axis_tkeep(tkeep),.m_axis_tvalid(tvalid),.m_axis_tlast(tlast),
 .m_axis_tready(tready),.busy(busy),.done(done),.overflow(overflow));
 wire [31:0] car_control,car_status;
 wire car_mode;
 car_motor motors(.clk(clk),.resetn(resetn),.key_n(mode_key_n),.control(car_control),.status(car_status),.car_mode(car_mode),
 .pwm_a(motor_pwm_a),.ain1(motor_ain1),.ain2(motor_ain2),.pwm_b(motor_pwm_b),.bin1(motor_bin1),.bin2(motor_bin2),.stby(motor_stby),.mode_led(mode_led),.drive_led(drive_led));
 wire servo_fault;
 wire [11:0] pan_actual_us,tilt_actual_us;
 servo_pwm servos(.clk(clk),.resetn(resetn),.enable(control[26:25]),
 .pan_center(car_mode),.heartbeat(control[27]),.hold_position(control[28]),.pan_us(control[12:1]),.tilt_us(control[24:13]),
 .pan_pwm(servo_pan_pwm),.tilt_pwm(servo_tilt_pwm),.fault(servo_fault),
 .pan_actual_us(pan_actual_us),.tilt_actual_us(tilt_actual_us));
 assign status={3'b0,tilt_actual_us,pan_actual_us,servo_fault,sync_error,overflow,done,busy};
 wire [31:0] camera_control,camera_status,direction_control;
 camera_display camera(.direction_control(direction_control),.clk(clk),.resetn(resetn),.control(camera_control),.status(camera_status),
 .camera_pclk(camera_pclk),.camera_vsync(camera_vsync),.camera_href(camera_href),.camera_data(camera_data),
 .camera_xclk(camera_xclk),.camera_scl(camera_scl),.camera_sda(camera_sda),
 .hdmi_clk_p(hdmi_clk_p),.hdmi_clk_n(hdmi_clk_n),.hdmi_d_p(hdmi_d_p),.hdmi_d_n(hdmi_d_n));
 system_wrapper system_i(
 .DDR_addr(DDR_addr),.DDR_ba(DDR_ba),.DDR_cas_n(DDR_cas_n),.DDR_ck_n(DDR_ck_n),
 .DDR_ck_p(DDR_ck_p),.DDR_cke(DDR_cke),.DDR_cs_n(DDR_cs_n),.DDR_dm(DDR_dm),
 .DDR_dq(DDR_dq),.DDR_dqs_n(DDR_dqs_n),.DDR_dqs_p(DDR_dqs_p),.DDR_odt(DDR_odt),
 .DDR_ras_n(DDR_ras_n),.DDR_reset_n(DDR_reset_n),.DDR_we_n(DDR_we_n),
 .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),.FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
 .FIXED_IO_mio(FIXED_IO_mio),.FIXED_IO_ps_clk(FIXED_IO_ps_clk),
 .FIXED_IO_ps_porb(FIXED_IO_ps_porb),.FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
.car_control(car_control),.car_status(car_status),.direction_control(direction_control),.camera_control(camera_control),.camera_status(camera_status),
 .clk_100(clk),.resetn(resetn),.control(control),.status(status),
 .mic_axis_tdata(tdata),.mic_axis_tkeep(tkeep),.mic_axis_tvalid(tvalid),
 .mic_axis_tlast(tlast),.mic_axis_tready(tready));
endmodule
