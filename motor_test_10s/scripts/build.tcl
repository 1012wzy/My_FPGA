set root [file normalize [file join [file dirname [info script]] ..]]
create_project -force motor_test [file join $root vivado_project] -part xc7z100ffg900-2
set_property target_language Verilog [current_project]
add_files [glob [file join $root rtl *.v]]
add_files -fileset constrs_1 [file join $root constraints motor_test.xdc]
add_files -fileset sim_1 [file join $root sim tb_motor_cycle.sv]
set_property top motor_test_top [get_filesets sources_1]
set_property top tb_motor_cycle [get_filesets sim_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {![string match {*write_bitstream Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
open_run impl_1
report_timing_summary -delay_type min_max -report_unconstrained -file [file join $root reports timing.rpt]
report_drc -file [file join $root reports drc.rpt]
report_utilization -file [file join $root reports utilization.rpt]
foreach type {max min} {if {[llength [get_timing_paths -quiet -delay_type $type -slack_lesser_than 0 -max_paths 1]]} {error "Timing failed"}}
if {[llength [get_drc_violations -quiet -filter {SEVERITY == "Error" || SEVERITY == "Critical Warning"}]]} {error "DRC failed"}
foreach {port pin} {sys_clk_p D9 sys_clk_n D8 mode_key_n U29 mode_led W24 drive_led V23 fep_power_en AH26 servo_pan_pwm AD30 servo_tilt_pwm AE30 motor_pwm_a Y28 motor_ain1 AB27 motor_ain2 AA27 motor_pwm_b Y26 motor_bin1 Y30 motor_bin2 AB29 motor_stby AA29} {
 if {[get_property PACKAGE_PIN [get_ports $port]] ne $pin} {error "Pin mismatch: $port"}
}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] motor_test_top.bit] [file join $root output motor_test_top.bit]
puts MOTOR_TEST_BUILD_OK
close_project
