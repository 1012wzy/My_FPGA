# Read-only hardware check. No reset, download, erase, or flash write.
connect -url tcp:127.0.0.1:3121
# hw_server can report an empty target list briefly while enumerating a cable.
set fpga {}
for {set attempt 0} {$attempt < 6} {incr attempt} {
 set fpga [targets -target-properties -filter {name =~ "xc7z*"}]
 if {[llength $fpga] != 0} {break}
 after 1000
}
if {[llength $fpga] != 1} {error "Connect exactly one Zynq board. Found [llength $fpga]."}
set name [dict get [lindex $fpga 0] name]
if {![string match -nocase "xc7z100*" $name]} {error "Expected xc7z100, found $name"}
set cpus [targets -target-properties -filter {name =~ "ARM Cortex-A9 MPCore #0"}]
if {[llength $cpus] != 1} {error "Expected exactly one ARM Cortex-A9 CPU0"}
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
set bootmode [mrd -value 0xf800025c]
if {[llength $bootmode] != 1 || ![regexp {^(0[xX])?[0-9a-fA-F]{1,8}$} [lindex $bootmode 0]]} {error "Invalid BOOT_MODE register value: $bootmode"}
if {[scan [lindex $bootmode 0] %x rawmode] != 1} {error "Cannot parse BOOT_MODE register: $bootmode"}
set mode [expr {$rawmode & 15}]
if {$mode != 0} {error [format "Boot mode is 0x%x, not JTAG. Power OFF, set core switch 1=ON 2=ON, then power ON." $mode]}
puts "QSPI_PREFLIGHT_OK: xc7z100, boot mode JTAG"
disconnect
