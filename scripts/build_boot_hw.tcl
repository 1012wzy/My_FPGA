set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root boot_qspi]
set work [file join $out init_hw]
file mkdir $work
set ::env(TEMP) [file join $root .build_tmp]
set ::env(TMP) $::env(TEMP)
# Export the existing BD as Tcl, then recreate it with fresh generated IP.
# Do not save or alter the original project.
open_project [file join $root soc_prj SXCX.xpr]
open_bd_design [get_files system.bd]
write_bd_tcl -force [file join $work recreate_system.tcl]
close_project
create_project -force boot_init [file join $work clean_project] -part xc7z100ffg900-2
source [file join $work recreate_system.tcl]
set before [list_property [get_bd_cells ps7]]
array set saved {}
foreach key $before {if {[string match CONFIG.* $key]} {set saved($key) [get_property $key [get_bd_cells ps7]]}}
set_property -dict [list CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6} CONFIG.PCW_QSPI_GRP_IO1_ENABLE {1} CONFIG.PCW_QSPI_GRP_IO1_IO {MIO 0 9 .. 13} CONFIG.PCW_DUAL_PARALLEL_QSPI_DATA_MODE {x8} CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {0} CONFIG.PCW_QSPI_GRP_SS1_ENABLE {0} CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {0} CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ {150}] [get_bd_cells ps7]
set changes [open [file join $out ps_config_changes.txt] w]
foreach key [lsort [array names saved]] {
 set now [get_property $key [get_bd_cells ps7]]
 if {$saved($key) ne $now} {puts $changes "$key: $saved($key) -> $now"}
}
close $changes
validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
write_hw_platform -fixed -force -file [file join $out boot_init.xsa]
puts "QSPI_BOOT_HW_READY: QSPI x8 parallel enabled; original CAR1 project and bitstream unchanged"
close_project
