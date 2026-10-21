# Logical 100 MHz system clock only. This is NOT a board pin assignment.
create_clock -name sys_clk -period 10.000 [get_ports clk]
# Before implementation: confirm actual clock source, PACKAGE_PIN, IOSTANDARD,
# board voltages, mic output delay, and input/output timing from schematics.
# sample0..sample6 and frame_valid are internal interfaces for a future system.
# Do not assign these sample buses to physical board pins merely to pass DRC.
