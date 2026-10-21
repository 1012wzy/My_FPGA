# Volatile standalone PL test. No PS application is started.
set root [file normalize [file join [file dirname [info script]] ..]]
connect -url tcp:127.0.0.1:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
rst -system
after 1500
targets -set -filter {name =~ "xc7z100*"}
fpga -file [file join $root output motor_test_top.bit]
puts "MOTOR_TEST_READY: wheels OFF. Raise wheels; BUT1 starts 10s forward / 1s coast / 10s reverse / 1s coast loop. BUT1 stops."
disconnect
