# CEPX3 J4: pin1=3V3, pin2=GND. No power pins are GPIO.
# J4-3 CEP3_6P -> FEP B6 -> Y28. J4-4 CEP3_6N -> B7 -> AA29.
# J4-5 CEP3_5P -> B8 -> AB27. J4-9 CEP3_4P -> B4 -> AA27.
# J4-11 CEP3_3P -> A4 -> Y26. J4-13 CEP3_2P -> A6 -> Y30.
# J4-15 CEP3_1P -> A8 -> AB29. BANK12 VADJ2 remains 3V3.
set_property PACKAGE_PIN Y28 [get_ports motor_pwm_a]
set_property PACKAGE_PIN AB27 [get_ports motor_ain1]
set_property PACKAGE_PIN AA27 [get_ports motor_ain2]
set_property PACKAGE_PIN Y26 [get_ports motor_pwm_b]
set_property PACKAGE_PIN Y30 [get_ports motor_bin1]
set_property PACKAGE_PIN AB29 [get_ports motor_bin2]
set_property PACKAGE_PIN AA29 [get_ports motor_stby]
set_property IOSTANDARD LVCMOS33 [get_ports {motor_pwm_a motor_ain1 motor_ain2 motor_pwm_b motor_bin1 motor_bin2 motor_stby}]
set_property DRIVE 8 [get_ports {motor_pwm_a motor_ain1 motor_ain2 motor_pwm_b motor_bin1 motor_bin2 motor_stby}]
set_property SLEW SLOW [get_ports {motor_pwm_a motor_ain1 motor_ain2 motor_pwm_b motor_bin1 motor_bin2 motor_stby}]
# MLK-H3 schematic page16: BUT1 pulled to 3V3, press pulls low.
set_property PACKAGE_PIN U29 [get_ports mode_key_n]
set_property IOSTANDARD LVCMOS33 [get_ports mode_key_n]
set_property PULLUP true [get_ports mode_key_n]
set_false_path -from [get_ports mode_key_n] -to [get_cells -hier -filter {NAME =~ *motors/key_meta_reg}]
set_property PACKAGE_PIN W24 [get_ports mode_led]
set_property PACKAGE_PIN V23 [get_ports drive_led]
set_property IOSTANDARD LVCMOS33 [get_ports {mode_led drive_led}]
set_property DRIVE 4 [get_ports {mode_led drive_led}]
set_property SLEW SLOW [get_ports {mode_led drive_led}]
# Motor/LED outputs are asynchronous to external devices; constrain pad delay.
set_max_delay 10.000 -datapath_only -from [all_registers -clock [get_clocks sys_clk]] -to [get_ports {motor_pwm_a motor_ain1 motor_ain2 motor_pwm_b motor_bin1 motor_bin2 motor_stby mode_led drive_led}]
