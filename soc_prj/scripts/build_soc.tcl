set root [file normalize [file join [file dirname [info script]] ..]]
set temp_dir [file normalize [file join $root .. .build_tmp]]
file mkdir $temp_dir
set ::env(TEMP) $temp_dir
set ::env(TMP) $temp_dir
open_project [file join $root SXCX.xpr]
foreach stale {camera_axis_capture.v video_axis_scan.v} {set f [get_files -quiet *$stale];if {[llength $f]} {remove_files $f}}
set_property XPM_LIBRARIES {XPM_CDC} [current_project]
foreach name {mic_axis_packet.v mic_soc_top.v car_motor.v servo_pwm.v camera_frame_store.v sound_direction_cdc.v sound_marker_cdc.v sound_overlay.v camera_display.v dvi_encode.v dvi_serialize.v} {
 set f [file join $root SXCX.srcs sources_1 new $name]
 if {![llength [get_files -quiet $f]]} {add_files -norecurse $f}
}
set bdfile [get_files -quiet */system.bd]
if {![llength $bdfile]} {
 create_bd_design system
 create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7
 source [file join $root scripts vendor_ps_preset.tcl]
 set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_USE_S_AXI_HP0 {1} \
 CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_EN_RST0_PORT {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} \
 CONFIG.PCW_SD1_PERIPHERAL_ENABLE {0} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0}] [get_bd_cells ps7]
 make_bd_intf_pins_external [get_bd_intf_pins ps7/DDR]
 make_bd_intf_pins_external [get_bd_intf_pins ps7/FIXED_IO]
 create_bd_port -dir I -type clk -freq_hz 100000000 clk_100
 set_property CONFIG.FREQ_HZ 100000000 [get_bd_ports clk_100]
 create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst
 # Reset polarity is inferred from PS FCLK_RESET0_N.
 create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
 set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
 connect_bd_net [get_bd_pins one/dout] [get_bd_pins rst/dcm_locked]
 connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins rst/ext_reset_in]
 create_bd_port -dir O -type rst resetn
 set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports resetn]
 connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_ports resetn]
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 dma
 set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_include_mm2s {0} \
 CONFIG.c_sg_length_width {23} CONFIG.c_m_axis_mm2s_tdata_width {32} \
 CONFIG.c_s_axis_s2mm_tdata_width {32} CONFIG.c_include_s2mm_dre {0}] [get_bd_cells dma]
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 gpio
 set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells gpio]
 create_bd_port -dir O -from 31 -to 0 control
 create_bd_port -dir I -from 31 -to 0 status
 connect_bd_net [get_bd_pins gpio/gpio_io_o] [get_bd_ports control]
 connect_bd_net [get_bd_pins gpio/gpio2_io_i] [get_bd_ports status]
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 cfg_ic
 set_property CONFIG.NUM_MI 2 [get_bd_cells cfg_ic]
 connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins cfg_ic/S00_AXI]
 connect_bd_intf_net [get_bd_intf_pins cfg_ic/M00_AXI] [get_bd_intf_pins dma/S_AXI_LITE]
 connect_bd_intf_net [get_bd_intf_pins cfg_ic/M01_AXI] [get_bd_intf_pins gpio/S_AXI]
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 mem_ic
 set_property CONFIG.NUM_MI 1 [get_bd_cells mem_ic]
 connect_bd_intf_net [get_bd_intf_pins dma/M_AXI_S2MM] [get_bd_intf_pins mem_ic/S00_AXI]
 connect_bd_intf_net [get_bd_intf_pins mem_ic/M00_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
 create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 mic_axis
 set_property -dict [list CONFIG.TDATA_NUM_BYTES {4} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.FREQ_HZ {100000000}] [get_bd_intf_ports mic_axis]
 connect_bd_intf_net [get_bd_intf_ports mic_axis] [get_bd_intf_pins dma/S_AXIS_S2MM]
 set_property CONFIG.ASSOCIATED_BUSIF mic_axis [get_bd_ports clk_100]
 foreach p {ps7/M_AXI_GP0_ACLK ps7/S_AXI_HP0_ACLK rst/slowest_sync_clk dma/s_axi_lite_aclk dma/m_axi_s2mm_aclk gpio/s_axi_aclk cfg_ic/ACLK cfg_ic/S00_ACLK cfg_ic/M00_ACLK cfg_ic/M01_ACLK mem_ic/ACLK mem_ic/S00_ACLK mem_ic/M00_ACLK} {
  connect_bd_net [get_bd_ports clk_100] [get_bd_pins $p]
 }
 foreach p {dma/axi_resetn gpio/s_axi_aresetn cfg_ic/ARESETN cfg_ic/S00_ARESETN cfg_ic/M00_ARESETN cfg_ic/M01_ARESETN mem_ic/ARESETN mem_ic/S00_ARESETN mem_ic/M00_ARESETN} {
  connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins $p]
 }
 assign_bd_address
 set_property offset 0x40400000 [get_bd_addr_segs ps7/Data/SEG_dma_Reg]
 set_property offset 0x41200000 [get_bd_addr_segs ps7/Data/SEG_gpio_Reg]
 validate_bd_design
 save_bd_design
} else {open_bd_design $bdfile; validate_bd_design; save_bd_design}
# Camera configuration/status GPIO; original audio register map is unchanged.
if {![llength [get_bd_cells -quiet camera_gpio]]} {
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 camera_gpio
 set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells camera_gpio]
 create_bd_port -dir O -from 31 -to 0 camera_control
 create_bd_port -dir I -from 31 -to 0 camera_status
 connect_bd_net [get_bd_pins camera_gpio/gpio_io_o] [get_bd_ports camera_control]
 connect_bd_net [get_bd_pins camera_gpio/gpio2_io_i] [get_bd_ports camera_status]
 set_property CONFIG.NUM_MI 3 [get_bd_cells cfg_ic]
 connect_bd_intf_net [get_bd_intf_pins cfg_ic/M02_AXI] [get_bd_intf_pins camera_gpio/S_AXI]
 foreach p {camera_gpio/s_axi_aclk cfg_ic/M02_ACLK} {connect_bd_net [get_bd_ports clk_100] [get_bd_pins $p]}
 foreach p {camera_gpio/s_axi_aresetn cfg_ic/M02_ARESETN} {connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins $p]}
 assign_bd_address -offset 0x41210000 -range 64K -target_address_space [get_bd_addr_spaces ps7/Data] [get_bd_addr_segs camera_gpio/S_AXI/Reg]
}
source [file join $root scripts configure_video_bram.tcl]
# Independent output-only telemetry GPIO; audio/camera registers retain addresses.
set_property CONFIG.NUM_MI 5 [get_bd_cells cfg_ic]
if {![llength [get_bd_cells -quiet direction_gpio]]} {
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 direction_gpio
 set_property -dict [list CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_GPIO_WIDTH {32}] [get_bd_cells direction_gpio]
 create_bd_port -dir O -from 31 -to 0 direction_control
 connect_bd_net [get_bd_pins direction_gpio/gpio_io_o] [get_bd_ports direction_control]
 connect_bd_intf_net [get_bd_intf_pins cfg_ic/M03_AXI] [get_bd_intf_pins direction_gpio/S_AXI]
 foreach p {direction_gpio/s_axi_aclk cfg_ic/M03_ACLK} {connect_bd_net [get_bd_ports clk_100] [get_bd_pins $p]}
 foreach p {direction_gpio/s_axi_aresetn cfg_ic/M03_ARESETN} {connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins $p]}
 assign_bd_address -offset 0x41220000 -range 64K -target_address_space [get_bd_addr_spaces ps7/Data] [get_bd_addr_segs direction_gpio/S_AXI/Reg]
}
# Dual GPIO for bounded wheel commands and hardware mode/watchdog status.
if {![llength [get_bd_cells -quiet car_gpio]]} {
 create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 car_gpio
 set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_GPIO_WIDTH {32} CONFIG.C_GPIO2_WIDTH {32}] [get_bd_cells car_gpio]
 create_bd_port -dir O -from 31 -to 0 car_control
 create_bd_port -dir I -from 31 -to 0 car_status
 connect_bd_net [get_bd_pins car_gpio/gpio_io_o] [get_bd_ports car_control]
 connect_bd_net [get_bd_pins car_gpio/gpio2_io_i] [get_bd_ports car_status]
 connect_bd_intf_net [get_bd_intf_pins cfg_ic/M04_AXI] [get_bd_intf_pins car_gpio/S_AXI]
 foreach p {car_gpio/s_axi_aclk cfg_ic/M04_ACLK} {connect_bd_net [get_bd_ports clk_100] [get_bd_pins $p]}
 foreach p {car_gpio/s_axi_aresetn cfg_ic/M04_ARESETN} {connect_bd_net [get_bd_pins rst/peripheral_aresetn] [get_bd_pins $p]}
 assign_bd_address -offset 0x41230000 -range 64K -target_address_space [get_bd_addr_spaces ps7/Data] [get_bd_addr_segs car_gpio/S_AXI/Reg]
}
set car_xdc [file join $root SXCX.srcs constrs_1 new car_motor.xdc]
if {![llength [get_files -quiet $car_xdc]]} {add_files -fileset constrs_1 -norecurse $car_xdc}
foreach name {camera_display_clocks camera_xclk_ip} {
 if {![llength [get_ips -quiet $name]]} {create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $name}
}
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.NUM_OUT_CLKS {2} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {371.250} CONFIG.USE_RESET {true} CONFIG.RESET_TYPE {ACTIVE_HIGH}] [get_ips camera_display_clocks]
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.NUM_OUT_CLKS {1} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {24.000} CONFIG.USE_RESET {true} CONFIG.RESET_TYPE {ACTIVE_HIGH}] [get_ips camera_xclk_ip]
generate_target all [get_ips {camera_display_clocks camera_xclk_ip}]
set camera_xdc [file join $root SXCX.srcs constrs_1 new camera_display.xdc]
if {![llength [get_files -quiet $camera_xdc]]} {add_files -fileset constrs_1 -norecurse $camera_xdc}
foreach intf {DDR FIXED_IO} {
 if {[llength [get_bd_intf_ports -quiet ${intf}_0]]} {set_property name $intf [get_bd_intf_ports ${intf}_0]}
}
validate_bd_design
save_bd_design
set bdfile [get_files */system.bd]
generate_target all $bdfile
set wrappers [make_wrapper -files $bdfile -top]
foreach f $wrappers {if {![llength [get_files -quiet $f]]} {add_files -norecurse $f}}
set_property top mic_soc_top [get_filesets sources_1]
set_property is_enabled false [get_files *mic_array_clock.xdc]
set_property is_enabled true [get_files *mic_board.xdc]
update_compile_order -fileset sources_1
foreach run [get_runs -filter {IS_SYNTHESIS == 1}] {
 if {$run ne "synth_1"} {reset_runs $run}
}
reset_runs synth_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "SoC synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match {*write_bitstream Complete*} [get_property STATUS [get_runs impl_1]]]} {error "SoC route failed"}
open_run impl_1
set out [file normalize [file join $root .. soc_hw]]
set reports [file join $root reports soc]
file mkdir $reports
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $reports timing.rpt]
report_drc -file [file join $reports drc.rpt]
set cdc [report_cdc -details -return_string]
set cdcfile [open [file join $reports cdc.rpt] w]
puts $cdcfile $cdc
close $cdcfile
if {[regexp {CDC-[0-9]+[ \t]+Critical} $cdc]} {error "Critical CDC needs review"}
report_utilization -file [file join $reports utilization.rpt]
foreach type {max min} {if {[llength [get_timing_paths -quiet -delay_type $type -slack_lesser_than 0 -max_paths 1]]} {error "Timing failed"}}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == "Error" || SEVERITY == "Critical Warning"}]]} {error "Severe DRC"}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] mic_soc_top.bit] [file join $out mic_soc_top.bit]
write_hw_platform -fixed -include_bit -force -file [file join $out system_wrapper.xsa]
write_checkpoint -force [file join $out mic_soc_top_routed.dcp]
foreach {name expected} {clk_out1_camera_display_clocks 13.468 clk_out2_camera_display_clocks 2.694 clk_out1_camera_xclk_ip 41.667} {
 if {abs([get_property PERIOD [get_clocks $name]]-$expected)>0.01} {error "Incorrect video clock $name"}
}
source [file join $root scripts check_camera_pins.tcl]
source [file join $root scripts check_car_pins.tcl]
puts [exec {C:/Users/30831/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe} -I -X utf8 [file join $root .. scripts record_hardware.py]]
puts SOC_BUILD_OK
close_project
