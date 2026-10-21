# Optional calibration control; never required for ordinary operation.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root soc_hw debug_symbols.tcl]
set mode [lindex $argv 0]
if {$mode ne "0" && $mode ne "1"} {error "Expected mode0=tracking or1=hold"}
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
if {[expr {[mrd -value $g_marker_hold] & 0xffffffff}]!=0x484f4c44} {error "Matching diagnostic mailbox not present; download current software first"}
mwr [expr {$g_marker_hold+4}] $mode
after 100
if {[mrd -value [expr {$g_marker_hold+4}]]!=$mode} {error "Hold request readback failed"}
puts "MARKER_HOLD_REQUESTED: $mode (0=automatic tracking,1=hold current pose)"
disconnect
