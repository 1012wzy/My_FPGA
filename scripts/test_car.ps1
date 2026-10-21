$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$run=Join-Path $root '.build_tmp\car_tests'
New-Item -ItemType Directory -Path $run -Force | Out-Null
$reports=Join-Path $root 'soc_prj\reports'
$gcc='D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe'
& $gcc -O2 -Wall -Wextra -Werror -I "$root\soc_sdk\src" "$root\soc_sdk\tests\test_car.c" "$root\soc_sdk\src\car.c" -lm -o "$run\car.exe"
if($LASTEXITCODE){throw 'car host compile'}
& "$run\car.exe" | Tee-Object -FilePath "$reports\car_host_test.log"
if($LASTEXITCODE){throw 'car host tests'}
& $gcc -O2 -Wall -Wextra -Werror -I "$root\soc_sdk\src" "$root\soc_sdk\tests\test_car_presence.c" "$root\soc_sdk\src\car.c" "$root\soc_sdk\src\sound_marker.c" -lm -o "$run\car_presence.exe"
if($LASTEXITCODE){throw 'car presence compile'}
& "$run\car_presence.exe" | Tee-Object -FilePath "$reports\car_presence_test.log"
if($LASTEXITCODE){throw 'car presence tests'}
& $gcc -O2 -Wall -Wextra -Werror -I "$root\soc_sdk\src" "$root\soc_sdk\tests\car_lease_trace.c" "$root\soc_sdk\src\car.c" -lm -o "$run\car_lease_trace.exe"
if($LASTEXITCODE){throw 'lease trace compile'}
& "$run\car_lease_trace.exe" "$run\car_lease_trace.hex"
if($LASTEXITCODE){throw 'lease trace generation'}
$bin='D:\Xilinx\Install\2025.2\Vivado\bin'
Push-Location -LiteralPath $run
try {
 & "$bin\xvlog.bat" --sv "$root\soc_prj\SXCX.srcs\sources_1\new\car_motor.v" "$root\soc_prj\SXCX.srcs\sources_1\new\servo_pwm.v" "$root\soc_prj\scripts\test_support\tb_car_motor.sv" "$root\soc_prj\scripts\test_support\tb_servo_car.sv" "$root\soc_prj\scripts\test_support\tb_car_lease.sv" *> "$reports\car_rtl_compile.log"
 if($LASTEXITCODE){throw 'car RTL compile'}
 foreach($top in @('tb_car_motor','tb_servo_car','tb_car_lease')) {
  & "$bin\xelab.bat" "work.$top" -s $top -debug typical *> "$reports\$top.elaborate.log"
  if($LASTEXITCODE){throw "elaborate $top"}
  & "$bin\xsim.bat" $top -runall *> "$reports\$top.log"
  $log=Get-Content -LiteralPath "$reports\$top.log" -Raw
  if($LASTEXITCODE -or $log -notmatch 'PASS:' -or $log -match 'Fatal:|FATAL|ERROR:'){throw "test $top"}
  Write-Output "PASS: $top"
 }
} finally {Pop-Location}
Write-Output 'CAR_TESTS_OK'
