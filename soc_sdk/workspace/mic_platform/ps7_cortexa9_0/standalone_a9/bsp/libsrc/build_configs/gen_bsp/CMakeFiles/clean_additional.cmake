# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "D:\\Xilinx\\project\\My_FPGA\\soc_sdk\\workspace\\mic_platform\\ps7_cortexa9_0\\standalone_a9\\bsp\\include\\sleep.h"
  "D:\\Xilinx\\project\\My_FPGA\\soc_sdk\\workspace\\mic_platform\\ps7_cortexa9_0\\standalone_a9\\bsp\\include\\xiltimer.h"
  "D:\\Xilinx\\project\\My_FPGA\\soc_sdk\\workspace\\mic_platform\\ps7_cortexa9_0\\standalone_a9\\bsp\\include\\xtimer_config.h"
  "D:\\Xilinx\\project\\My_FPGA\\soc_sdk\\workspace\\mic_platform\\ps7_cortexa9_0\\standalone_a9\\bsp\\lib\\libxiltimer.a"
  )
endif()
