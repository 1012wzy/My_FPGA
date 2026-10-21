param([string]$Gcc='D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$build=Join-Path $root '.build_tmp\response_tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$src=Join-Path $root 'soc_sdk\src'
$exe=Join-Path $build 'response.exe'
& $Gcc '-O2' '-Wall' '-Wextra' '-Werror' '-I' $src (Join-Path $root 'soc_sdk\tests\test_response.c') (Join-Path $src 'sound_marker.c') (Join-Path $src 'servo.c') '-lm' '-o' $exe
if($LASTEXITCODE){throw 'Response test compile failed'}
& $exe | Tee-Object -FilePath (Join-Path $root 'soc_prj\reports\response_host_test.log')
if($LASTEXITCODE){throw 'Response test failed'}
