//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.2 (win64) Build 6299465 Fri Nov 14 19:35:11 GMT 2025
//Date        : Mon Oct  5 16:56:28 2026
//Host        : MaYiQun running 64-bit major release  (build 9200)
//Command     : generate_target system_wrapper.bd
//Design      : system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module system_wrapper
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
    clk_100,
    control,
    mic_axis_tdata,
    mic_axis_tkeep,
    mic_axis_tlast,
    mic_axis_tready,
    mic_axis_tvalid,
    resetn,
    car_control,
    car_status,
    direction_control,
    camera_control,
    camera_status,
    status);
  inout [14:0]DDR_addr;
  inout [2:0]DDR_ba;
  inout DDR_cas_n;
  inout DDR_ck_n;
  inout DDR_ck_p;
  inout DDR_cke;
  inout DDR_cs_n;
  inout [3:0]DDR_dm;
  inout [31:0]DDR_dq;
  inout [3:0]DDR_dqs_n;
  inout [3:0]DDR_dqs_p;
  inout DDR_odt;
  inout DDR_ras_n;
  inout DDR_reset_n;
  inout DDR_we_n;
  inout FIXED_IO_ddr_vrn;
  inout FIXED_IO_ddr_vrp;
  inout [53:0]FIXED_IO_mio;
  inout FIXED_IO_ps_clk;
  inout FIXED_IO_ps_porb;
  inout FIXED_IO_ps_srstb;
  input clk_100;
  output [31:0]control;
  input [31:0]mic_axis_tdata;
  input [3:0]mic_axis_tkeep;
  input mic_axis_tlast;
  output mic_axis_tready;
  input mic_axis_tvalid;
  output [0:0]resetn;
  input [31:0]status;
  input [31:0]camera_status;
  output [31:0]camera_control;
  output [31:0] direction_control;
  output [31:0] car_control;
  input [31:0] car_status;
  assign car_control=0;
  assign direction_control=0;
  assign camera_control=0;

// Simulation-only PS interface stub, never add to hardware fileset.
 reg [31:0] test_control=0;
 reg test_resetn=0,test_ready=0;
 assign control=test_control;
 assign resetn=test_resetn;
 assign mic_axis_tready=test_ready;
endmodule
