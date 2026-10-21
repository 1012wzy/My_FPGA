foreach {name pin bank} {motor_pwm_a Y28 12 motor_ain1 AB27 12 motor_ain2 AA27 12 motor_pwm_b Y26 12 motor_bin1 Y30 12 motor_bin2 AB29 12 motor_stby AA29 12 mode_key_n U29 13 mode_led W24 13 drive_led V23 13} {
 set p [get_ports $name]
 if {[get_property PACKAGE_PIN $p] ne $pin} {error "Incorrect car pin $name"}
 if {[get_property IOSTANDARD $p] ne "LVCMOS33"} {error "Incorrect car voltage $name"}
 if {[get_property BANK [get_package_pins $pin]] != $bank} {error "Incorrect bank $name"}
}
puts CAR_PIN_CHECK_OK
