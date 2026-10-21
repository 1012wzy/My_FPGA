# Check that the acquisition front end maps to the requested FPGA.
# OOC synthesis is not implementation, pin validation, or a downloadable bitstream.
set root [file normalize [file join [file dirname [info script]] ..]]
set rtl [file join $root SXCX.srcs sources_1 new]
set reports [file join $root reports]
file mkdir $reports
create_project -in_memory -part xc7z100ffg900-2
foreach name {mic_i2s_clock.v i2s_rx_pair.v mic_pair_top.v mic_array_top.v} {
    read_verilog [file join $rtl $name]
}
read_xdc [file join $root SXCX.srcs constrs_1 new mic_array_clock.xdc]
synth_design -top mic_array_top -part xc7z100ffg900-2 -mode out_of_context
report_utilization -file [file join $reports utilization_ooc.rpt]
report_timing_summary -report_unconstrained -file [file join $reports timing_ooc.rpt]
check_timing -verbose -file [file join $reports check_timing_ooc.rpt]
puts "OOC_SYNTHESIS_OK"
close_project
