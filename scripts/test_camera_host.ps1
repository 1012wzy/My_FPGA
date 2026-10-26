$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$gcc='D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe'
$build=Join-Path $root '.build_tmp\camera_host'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$exe=Join-Path $build 'camera_host.exe'
& $gcc -O2 -Wall -Wextra -Werror -Wno-unused-parameter -I "$root\soc_sdk\tests\camera_mock" -I "$root\soc_sdk\src" "$root\soc_sdk\tests\test_camera.c" "$root\soc_sdk\src\camera.c" -o $exe
if($LASTEXITCODE){throw 'Camera host compile failed'}
& $exe | Tee-Object -FilePath "$root\soc_prj\reports\zip_camera_host_test.log"
if($LASTEXITCODE){throw 'Camera host test failed'}
