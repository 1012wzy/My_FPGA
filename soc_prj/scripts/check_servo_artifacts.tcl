set root [file normalize [file join [file dirname [info script]] .. ..]]
open_checkpoint [file join $root soc_hw mic_soc_top_routed.dcp]
foreach {name pin} {servo_pan_pwm AD30 servo_tilt_pwm AE30} {
 if {[get_property PACKAGE_PIN [get_ports $name]] ne $pin} {error "Servo pin mismatch: $name"}
 if {[get_property IOSTANDARD [get_ports $name]] ne "LVCMOS33"} {error "Servo voltage mismatch"}
 puts "VERIFIED_SERVO_PIN $name $pin LVCMOS33"
}
report_io -file [file join $root soc_prj reports soc io.rpt]
puts SERVO_IO_OK
close_design
