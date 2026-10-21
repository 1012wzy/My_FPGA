param([string[]]$TestNames=@('tb_camera_store','tb_sound_marker_cdc','tb_sound_direction_cdc','tb_sound_overlay','tb_dvi_encode','tb_camera_display'))
$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$bin='D:\Xilinx\Install\2025.2\Vivado\bin'
$testDir=Join-Path $taskRoot '.build_tmp\camera_tests'
New-Item -ItemType Directory -Path $testDir -Force | Out-Null
Push-Location -LiteralPath $testDir
try {
$rtl=Join-Path $taskRoot 'soc_prj\SXCX.srcs\sources_1\new'
$tests=Join-Path $taskRoot 'soc_prj\scripts\test_support'
$reports=Join-Path $taskRoot 'soc_prj\reports'
$xpm='D:\Xilinx\Install\2025.2\Vivado\data\ip\xpm'
& "$bin\xvlog.bat" --sv "$xpm\xpm_cdc\hdl\xpm_cdc.sv" "$xpm\xpm_memory\hdl\xpm_memory.sv" "$xpm\xpm_fifo\hdl\xpm_fifo.sv" "D:\Xilinx\Install\2025.2\Vivado\data\verilog\src\glbl.v" "$rtl\camera_frame_store.v" "$rtl\sound_marker_cdc.v" "$rtl\sound_direction_cdc.v" "$rtl\sound_overlay.v" "$rtl\dvi_encode.v" "$rtl\dvi_serialize.v" "$rtl\camera_display.v" "$tests\camera_clock_models.v" "$tests\tb_camera_store.sv" "$tests\tb_sound_marker_cdc.sv" "$tests\tb_sound_direction_cdc.sv" "$tests\tb_sound_overlay.sv" "$tests\tb_dvi_encode.sv" "$tests\tb_camera_display.sv" *> "$reports\zip_camera_compile.log"
if($LASTEXITCODE){throw 'camera compile failed'}
foreach($top in $TestNames){
 & "$bin\xelab.bat" "work.$top" work.glbl -L unisims_ver -L secureip -s $top -debug typical *> "$reports\$top.elaborate.log"
 if($LASTEXITCODE){throw "elaborate failed $top"}
 & "$bin\xsim.bat" $top -runall *> "$reports\$top.log"
 $log=Get-Content -LiteralPath "$reports\$top.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS:' -or $log -match 'Fatal:|FATAL|ERROR:'){throw "simulation failed $top"}
 Write-Output "PASS: $top"
}
Write-Output 'CAMERA_TESTS_OK'

} finally { Pop-Location }
