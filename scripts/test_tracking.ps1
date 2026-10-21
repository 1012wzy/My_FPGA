param([string]$Gcc='D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$build=Join-Path $root '.build_tmp\tracking_tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
foreach($name in @('servo','servo_startup')) {
 $argsList=@('-O2','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'soc_sdk\src'),(Join-Path $root "soc_sdk\tests\test_$name.c"),(Join-Path $root 'soc_sdk\src\servo.c'))
 if($name -eq 'servo_startup'){$argsList+=(Join-Path $root 'soc_sdk\src\servo_startup.c')}
 $exe=Join-Path $build "$name.exe"
 & $Gcc @argsList '-lm' '-o' $exe
 if($LASTEXITCODE -ne 0){throw "Compile failed: $name"}
 $log=if($name -eq 'servo'){'zip_servo_host_test.log'}else{'servo_startup_test.log'}
 & $exe | Tee-Object -FilePath (Join-Path $root "soc_prj\reports\$log")
 if($LASTEXITCODE -ne 0){throw "Host test failed: $name"}
}
& (Join-Path $PSScriptRoot 'test_marker.ps1') -Gcc $Gcc

$traceExe=Join-Path $build 'marker_trace.exe'
& $Gcc '-O2' '-Wall' '-Wextra' '-Werror' '-I' (Join-Path $root 'soc_sdk\src') (Join-Path $root 'soc_sdk\tests\test_marker_trace.c') (Join-Path $root 'soc_sdk\src\sound_marker.c') (Join-Path $root 'soc_sdk\src\servo.c') '-lm' '-o' $traceExe
if($LASTEXITCODE -ne 0){throw 'Trace test compile failed'}
Set-Content -LiteralPath (Join-Path $root 'soc_prj\reports\response_trace_replay.log') -Value '' -Encoding Unicode
foreach($spec in @(@('marker_trace_background.csv','1'),@('marker_trace_fixed_source.csv','0'))){
 & $traceExe (Join-Path $root ('soc_prj\reports\'+$spec[0])) $spec[1] | Tee-Object -FilePath (Join-Path $root 'soc_prj\reports\response_trace_replay.log') -Append
 if($LASTEXITCODE -ne 0){throw 'Trace replay failed'}
}

$presenceExe=Join-Path $build 'presence.exe'
& $Gcc '-O2' '-Wall' '-Wextra' '-Werror' '-I' (Join-Path $root 'soc_sdk\src') (Join-Path $root 'soc_sdk\tests\test_presence.c') (Join-Path $root 'soc_sdk\src\background.c') (Join-Path $root 'soc_sdk\src\sound_marker.c') (Join-Path $root 'soc_sdk\src\servo.c') '-lm' '-o' $presenceExe
if($LASTEXITCODE -ne 0){throw 'Presence integration test compile failed'}
& $presenceExe | Tee-Object -FilePath (Join-Path $root 'soc_prj\reports\presence_host_test.log')
if($LASTEXITCODE -ne 0){throw 'Presence integration test failed'}

& (Join-Path $PSScriptRoot 'test_response.ps1') -Gcc $Gcc
Write-Output 'NONPID_TRACKING_TESTS_OK'
