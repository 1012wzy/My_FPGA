param([string]$Gcc='D:\Xilinx\Install\2025.2\tps\mingw\8.3.0\win64.o\nt\bin\gcc.exe')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$build=Join-Path $root '.build_tmp\marker_tests'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$log=Join-Path $root 'soc_prj\reports\sound_marker_host_test.log'
Set-Content -LiteralPath $log -Value '' -Encoding utf8
foreach($mode in @('configured','zero_offset')) {
    $options=@('-O2','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'soc_sdk\src'))
    if($mode -eq 'zero_offset'){$options+=@('-DMARKER_OFFSET_X=0.f','-DMARKER_OFFSET_Y=0.f')}
    $exe=Join-Path $build ($mode+'.exe')
    & $Gcc @options (Join-Path $root 'soc_sdk\tests\test_sound_marker.c') (Join-Path $root 'soc_sdk\src\sound_marker.c') '-lm' '-o' $exe
    if($LASTEXITCODE -ne 0){throw "Marker test compile failed: $mode"}
    $result=& $exe
    $result | Add-Content -LiteralPath $log -Encoding utf8
    $result | Write-Output
    if($LASTEXITCODE -ne 0){throw "Marker test failed: $mode"}
}
