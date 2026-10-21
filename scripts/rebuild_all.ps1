$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
$env:TEMP=Join-Path $taskRoot '.build_tmp'
$env:TMP=$env:TEMP
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
& 'D:\Xilinx\Install\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -log soc_prj/reports/zip_camera_build.log -source soc_prj/scripts/build_soc.tcl *> soc_prj/reports/zip_camera_build_console.log
if($LASTEXITCODE -ne 0 -or (Get-Content soc_prj/reports/zip_camera_build_console.log -Raw) -notmatch '(?m)^SOC_BUILD_OK\s*$'){throw 'Hardware build failed; inspect zip_camera_build_console.log'}
& 'D:\Xilinx\Install\2025.2\Vitis\bin\vitis.bat' -s scripts/build_vitis.py *> soc_prj/reports/zip_camera_vitis_build.log
if($LASTEXITCODE -ne 0 -or (Get-Content soc_prj/reports/zip_camera_vitis_build.log -Raw) -notmatch 'VITIS_BUILD_OK:'){throw 'Software build failed; inspect zip_camera_vitis_build.log'}
Write-Output 'ZIP_BASE_CAMERA_BUILD_OK'
