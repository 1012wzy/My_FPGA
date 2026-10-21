set task_root [file normalize [file join [file dirname [info script]] .. ..]]
source [file join $task_root soc_hw debug_symbols.tcl]
proc connect {args} {}
proc targets {args} {}
proc disconnect {args} {}
proc mrd {flag address count} {
 global g_camera g_tracking g_marker g_car
 if {$flag ne "-value"} {error "unexpected mrd mode"}
 if {$address==$g_camera && $count==14} {return {4294967293 22080 12298 287 16 1 400 300 20 18 2 0 0 1128354353}}
 if {$address==$g_tracking && $count==17} {return {2 16 32 0 4294967290 16 4294967280 1 0 1500 1600 1500 1600 41 52 10 32}}
 if {$address==$g_marker && $count==8} {return {1 1200 1400 650 40 200 3500 4294965296}}
 if {$address==$g_car && $count==16} {return {1128354353 1 0 3238002688 0 0 0 0 0 4294967295 0 0 64 38 300 0}}
 error "unexpected memory read"
}
source [file join $task_root scripts read_status.tcl]
if {[signed32 4294967293] != -3} {error "signed conversion"}
if {[lindex [words $g_camera 14] 4] != 16} {error "decimal conversion"}
if {[lindex [words $g_camera 14] 1]!=0x5640} {error "sensor ID conversion"}
if {[lindex [words $g_tracking 17] 10]!=1600} {error "PWM conversion"}
if {[signed32 [lindex [words $g_marker 8] 7]] != -2000} {error "marker elevation conversion"}
puts STATUS_SCRIPT_OFFLINE_OK
