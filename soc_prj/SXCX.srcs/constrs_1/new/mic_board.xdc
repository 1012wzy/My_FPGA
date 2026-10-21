# MLK-H3 VER20240320 + CZ08 XC7Z100 FFG900 + CEPX3 3V3.
# Core schematic p3 + vendor 7100 demo: AC-coupled 100 MHz, BANK34 at 1.35 V.
set_property PACKAGE_PIN D9 [get_ports sys_clk_p]
set_property PACKAGE_PIN D8 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_SSTL135 [get_ports {sys_clk_p sys_clk_n}]
create_clock -name sys_clk -period 10.000 [get_ports sys_clk_p]

# CEP2: 3=BCLK, 4=WS, 5=D0, 6=D1, 9=D2, 10=D3. VADJ2 MUST be 3.3 V.
set_property PACKAGE_PIN AC29 [get_ports mic_bclk]
set_property PACKAGE_PIN AD29 [get_ports mic_ws]
set_property PACKAGE_PIN AC26 [get_ports {mic_data[0]}]
set_property PACKAGE_PIN AD26 [get_ports {mic_data[1]}]
set_property PACKAGE_PIN AD25 [get_ports {mic_data[2]}]
set_property PACKAGE_PIN AE26 [get_ports {mic_data[3]}]
set_property PACKAGE_PIN AH26 [get_ports fep_power_en]
# AH26 is the CEPX3 regulator enable request, driven HIGH by this 3V3 build.
# Power itself is supplied by the daughtercard regulator via CEP2 pin 1.
set_property IOSTANDARD LVCMOS33 [get_ports {mic_bclk mic_ws mic_data[*] fep_power_en}]
set_property DRIVE 8 [get_ports {mic_bclk mic_ws fep_power_en}]
set_property SLEW SLOW [get_ports {mic_bclk mic_ws fep_power_en}]
set_property PULLDOWN true [get_ports {mic_data[*]}]

# The external return is intentionally oversampled through 2-FF synchronizers.
# Exempt ONLY pad -> first FF. All first -> second FF paths remain timed.
# This does NOT prove the microphone output's settling time within each I2S bit.
set mic_first [get_cells -hier -filter {NAME =~ *data_meta_reg || NAME =~ *raw_meta_reg*}]
set_false_path -from [get_ports {mic_data[*]}] -to $mic_first
# Engineering pad-path budget: one 100 MHz cycle, versus 160 ns BCLK half-period.
# Includes the SLOW-slew OBUF delay; not a microphone tCO guarantee.
set_max_delay 10.000 -datapath_only -from [get_cells -hier -filter {NAME =~ *mic_bclk_reg || NAME =~ *mic_ws_reg}] -to [get_ports {mic_bclk mic_ws}]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullnone [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# CEPX3 J3/CEP2 11 -> U1A A17 -> H3 U45A A17 -> BANK12 AD30.
# CEPX3 J3/CEP2 12 -> U1A A18 -> H3 U45A A18 -> BANK12 AE30.
set_property PACKAGE_PIN AD30 [get_ports servo_pan_pwm]
set_property PACKAGE_PIN AE30 [get_ports servo_tilt_pwm]
set_property IOSTANDARD LVCMOS33 [get_ports {servo_pan_pwm servo_tilt_pwm}]
set_property DRIVE 8 [get_ports {servo_pan_pwm servo_tilt_pwm}]
set_property SLEW SLOW [get_ports {servo_pan_pwm servo_tilt_pwm}]
set_max_delay 10.000 -datapath_only -from [get_cells -hier -filter {NAME =~ *pan_pwm_reg || NAME =~ *tilt_pwm_reg}] -to [get_ports {servo_pan_pwm servo_tilt_pwm}]
