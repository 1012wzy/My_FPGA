set_property CONFIG.PCW_USE_S_AXI_HP1 0 [get_bd_cells ps7]
foreach name {video_dma video_mem} {if {[llength [get_bd_cells -quiet $name]]} {delete_bd_objs [get_bd_cells $name]}}
foreach name {camera_axis video_axis} {if {[llength [get_bd_intf_ports -quiet $name]]} {delete_bd_objs [get_bd_intf_ports $name]}}
foreach name {video_fsync video_pixel_clk} {if {[llength [get_bd_ports -quiet $name]]} {delete_bd_objs [get_bd_ports $name]}}
if {[llength [get_bd_cells -quiet car_gpio]]} {set_property CONFIG.NUM_MI 5 [get_bd_cells cfg_ic]} elseif {[llength [get_bd_cells -quiet direction_gpio]]} {set_property CONFIG.NUM_MI 4 [get_bd_cells cfg_ic]} else {set_property CONFIG.NUM_MI 3 [get_bd_cells cfg_ic]}
set_property CONFIG.ASSOCIATED_BUSIF mic_axis [get_bd_ports clk_100]
