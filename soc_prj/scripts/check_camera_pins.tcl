# Run after opening the routed design; assert exact screenshot pin placement.
if {[get_property PACKAGE_PIN [get_ports {camera_xclk}]] ne "AE28"} {error "Pin mismatch: camera_xclk"}
if {[get_property PACKAGE_PIN [get_ports {camera_pclk}]] ne "AF28"} {error "Pin mismatch: camera_pclk"}
if {[get_property PACKAGE_PIN [get_ports {camera_vsync}]] ne "AJ28"} {error "Pin mismatch: camera_vsync"}
if {[get_property PACKAGE_PIN [get_ports {camera_href}]] ne "AJ29"} {error "Pin mismatch: camera_href"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[0]}]] ne "AJ30"} {error "Pin mismatch: camera_data[0]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[1]}]] ne "AG27"} {error "Pin mismatch: camera_data[1]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[2]}]] ne "AG26"} {error "Pin mismatch: camera_data[2]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[3]}]] ne "AF25"} {error "Pin mismatch: camera_data[3]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[4]}]] ne "AK30"} {error "Pin mismatch: camera_data[4]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[5]}]] ne "AE25"} {error "Pin mismatch: camera_data[5]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[6]}]] ne "AK26"} {error "Pin mismatch: camera_data[6]"}
if {[get_property PACKAGE_PIN [get_ports {camera_data[7]}]] ne "AJ26"} {error "Pin mismatch: camera_data[7]"}
if {[get_property PACKAGE_PIN [get_ports {camera_scl}]] ne "AH29"} {error "Pin mismatch: camera_scl"}
if {[get_property PACKAGE_PIN [get_ports {camera_sda}]] ne "AH28"} {error "Pin mismatch: camera_sda"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_clk_p}]] ne "U26"} {error "Pin mismatch: hdmi_clk_p"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_clk_n}]] ne "U27"} {error "Pin mismatch: hdmi_clk_n"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_p[0]}]] ne "W29"} {error "Pin mismatch: hdmi_d_p[0]"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_n[0]}]] ne "W30"} {error "Pin mismatch: hdmi_d_n[0]"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_p[1]}]] ne "T25"} {error "Pin mismatch: hdmi_d_p[1]"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_n[1]}]] ne "T24"} {error "Pin mismatch: hdmi_d_n[1]"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_p[2]}]] ne "R27"} {error "Pin mismatch: hdmi_d_p[2]"}
if {[get_property PACKAGE_PIN [get_ports {hdmi_d_n[2]}]] ne "T27"} {error "Pin mismatch: hdmi_d_n[2]"}
puts CAMERA_PIN_CHECK_OK
