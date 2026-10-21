
# Read-only JTAG snapshot. CPU is neither stopped nor reprogrammed.
set task_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $task_root soc_hw debug_symbols.tcl]
proc words {address count} {
 set result {}
 foreach value [mrd -value $address $count] {
  # XSCT -value returns Tcl integers (decimal on 2025.2), not display-format hex.
  if {![string is entier -strict $value]} {error "Unexpected memory value $value"}
  lappend result [expr {$value & 0xffffffff}]
 }
 if {[llength $result]!=$count} {error "Incomplete memory snapshot"}
 return $result
}
proc signed32 {v} {if {$v>=2147483648} {return [expr {$v-4294967296}]} {return $v}}
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
set observation_started [clock milliseconds]
set c [words $g_camera 14]
if {[lindex $c 13]!=0x43415231} {error "Board software is not the matching CAR1 release; download the complete current bit/ELF first"}
set t [words $g_tracking 17]
set m [words $g_marker 8]
puts [format "CAMERA: result=%d sensor_id=0x%04x last_register=0x%04x status=0x%02x displayed_frames=%d" [signed32 [lindex $c 0]] [lindex $c 1] [lindex $c 2] [lindex $c 3] [lindex $c 4]]
set s [lindex $c 3]
puts [format "VIDEO: display_clock=%d camera_clock=%d frame_available=%d malformed=%d image_fresh=%d image_stale=%d" [expr {($s>>2)&1}] [expr {($s>>3)&1}] [expr {($s>>4)&1}] [expr {($s>>6)&1}] [expr {($s>>9)&1}] [expr {($s>>10)&1}]]
puts [format "TRACKING: state=%d blocks=%d fault=%d az=%d el=%d valid=%d pan_target=%d tilt_target=%d pan_pwm=%d tilt_pwm=%d" [lindex $t 0] [lindex $t 1] [signed32 [lindex $t 4]] [signed32 [lindex $t 5]] [signed32 [lindex $t 6]] [lindex $t 7] [lindex $t 9] [lindex $t 10] [lindex $t 11] [lindex $t 12]]
puts [format "MARKER: requested=%d x=%d y=%d overlay_active=%d (lens calibration required)" [lindex $c 5] [lindex $c 6] [lindex $c 7] [expr {($s>>8)&1}]]
puts [format "PERFORMANCE: capture_ms=%d compute_ms=%d cycle_ms=%d max_compute_ms=%d valid_blocks=%d/%d noise_rms=%d" [lindex $t 13] [lindex $t 2] [lindex $t 14] [lindex $t 16] [lindex $t 15] [lindex $t 1] [signed32 [lindex $t 8]]]
set rejected [lindex $m 0]
set labels {}
foreach {mask label} {1 level 2 coherence 4 ambiguity 8 single_tone 16 invalid 32 trajectory_outlier 64 acquiring} {
 if {$rejected & $mask} {lappend labels $label}
}
if {$rejected==0} {set labels {accepted}}
puts [format "MARKER_QUALITY: reason=%s rms=%d threshold=%d coherence=%.3f margin=%.3f tonality=%.3f az=%.3f el=%.3f" [join $labels ,] [lindex $m 1] [lindex $m 2] [expr {[signed32 [lindex $m 3]]/1000.0}] [expr {[signed32 [lindex $m 4]]/1000.0}] [expr {[signed32 [lindex $m 5]]/1000.0}] [expr {[signed32 [lindex $m 6]]/1000.0}] [expr {[signed32 [lindex $m 7]]/1000.0}]]
# True input, completed and displayed frame counters; PS polls before hardware wrap.
after 1000
set later [words $g_camera 14]
set dt [expr {[clock milliseconds]-$observation_started}]
set delta [expr {([lindex $later 4]-[lindex $c 4]) & 0xffffffff}]
if {$dt>0} {
 set din [expr {([lindex $later 8]-[lindex $c 8]) & 0xffffffff}]
 set dgood [expr {([lindex $later 9]-[lindex $c 9]) & 0xffffffff}]
 puts [format "VIDEO_RATE: input_fps=%.2f complete_fps=%.2f display_fps=%.2f window_ms=%d" [expr {$din*1000.0/$dt}] [expr {$dgood*1000.0/$dt}] [expr {$delta*1000.0/$dt}] $dt]
}
puts [format "VIDEO_RECOVERY: attempts=%d stage=%d error=%d line_error=%d odd_byte=%d overrun=%d version=0x%08x" [lindex $later 10] [lindex $later 11] [signed32 [lindex $later 12]] [expr {([lindex $later 3]>>29)&1}] [expr {([lindex $later 3]>>30)&1}] [expr {([lindex $later 3]>>31)&1}] [lindex $later 13]]
set car [words $g_car 16]
puts [format "CAR: mode=%d stage=%d pl=0x%08x target_L=%d target_R=%d duty_L=%d duty_R=%d fresh=%d age_ms=%d steer=%.2f centered=%d" [lindex $car 1] [lindex $car 2] [lindex $car 3] [lindex $car 4] [lindex $car 5] [lindex $car 6] [lindex $car 7] [lindex $car 8] [lindex $car 9] [expr {[signed32 [lindex $car 10]]/1000.0}] [lindex $car 11]]
disconnect

puts STATUS_READ_OK
