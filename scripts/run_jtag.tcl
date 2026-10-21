# Volatile JTAG launch only; never programs QSPI/SD or changes boot switches.
set root [file normalize [file join [file dirname [info script]] ..]]
set elf [file join $root soc_sdk workspace mic_angle build mic_angle.elf]
set bit [file join $root soc_hw mic_soc_top.bit]
set init [file join $root soc_hw ps7_init.tcl]
foreach f [list $elf $bit $init] {if {![file exists $f]} {error "Missing build artifact: $f"}}
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
rst -system
after 1500
targets -set -filter {name =~ "xc7z100*"}
fpga -file $bit
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
source $init
ps7_init
ps7_post_config
dow $elf
con
puts "RUNNING: CAR1 display mode; wheels disabled. BUT1 toggles car mode; no UART needed. Keep quiet for about 8 seconds. Servos enable in sequence, then operating-background calibration runs before automatic tracking."
disconnect
