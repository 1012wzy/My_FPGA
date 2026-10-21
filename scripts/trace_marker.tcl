# Read-only snapshot stream; never stops CPU or writes target memory.
set root [file normalize [file join [file dirname [info script]] ..]]
source [file join $root soc_hw debug_symbols.tcl]
proc words {address count} {
 set result {}
 foreach value [mrd -value $address $count] {
  if {![string is entier -strict $value]} {error "Unexpected memory value $value"}
  lappend result [expr {$value & 0xffffffff}]
 }
 if {[llength $result]!=$count} {error "Incomplete memory snapshot"}
 return $result
}
proc s32 {v} {if {$v>=2147483648} {return [expr {$v-4294967296}]} {return $v}}
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
set c [words $g_camera 14]
if {[lindex $c 13]!=0x43415231} {error "Download matching CAR1 software before tracing"}
set f [open [file join $root soc_prj reports marker_trace.csv] w]
puts $f "ms,block,reason,rms,threshold,coherence,margin,tonality,az,el,visible,x,y,pan_pwm,tilt_pwm"
set started [clock milliseconds]
while {[clock milliseconds]-$started<10000} {
 set t [words $g_tracking 17]
 set m [words $g_marker 8]
 set c [words $g_camera 14]
 set row [list [expr {[clock milliseconds]-$started}] [lindex $t 1]]
 foreach v $m {lappend row [s32 $v]}
 lappend row [lindex $c 5] [lindex $c 6] [lindex $c 7] [lindex $t 11] [lindex $t 12]
 puts $f [join $row ,]
 after 100
}
close $f
disconnect
puts MARKER_TRACE_OK
