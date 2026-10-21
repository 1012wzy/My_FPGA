param([string]$VivadoBin='D:\Xilinx\Install\2025.2\Vivado\bin',[string]$VitisBin='D:\Xilinx\Install\2025.2\Vitis\bin')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$out=Join-Path $root 'boot_qspi'
$env:TEMP=Join-Path $root '.build_tmp';$env:TMP=$env:TEMP
New-Item -ItemType Directory -Path $env:TEMP,(Join-Path $out 'diagnostics') -Force | Out-Null
# Only remove the disposable boot-only Vivado project before recreating it.
$generated=[IO.Path]::GetFullPath((Join-Path $out 'init_hw\clean_project'))
$expected=[IO.Path]::GetFullPath((Join-Path $root 'boot_qspi\init_hw\clean_project'))
if($generated -ne $expected -or !$generated.StartsWith([IO.Path]::GetFullPath($root)+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Invalid boot build directory'}
if(Test-Path -LiteralPath $generated){
 if((Get-Item -LiteralPath $generated).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Refuse reparse point'}
 Remove-Item -LiteralPath $generated -Recurse -Force
}
Push-Location $root
try {
 & (Join-Path $VivadoBin 'vivado.bat') -mode batch -nojournal -log boot_qspi/diagnostics/boot_hw.log -source scripts/build_boot_hw.tcl *> boot_qspi/diagnostics/boot_hw_console.log
 if($LASTEXITCODE -ne 0 -or (Get-Content boot_qspi/diagnostics/boot_hw_console.log -Raw) -notmatch '(?m)^QSPI_BOOT_HW_READY:'){throw 'Boot platform build failed. See boot_qspi/diagnostics/boot_hw_console.log'}
 & (Join-Path $VitisBin 'vitis.bat') -s scripts/build_boot_fsbl.py *> boot_qspi/diagnostics/build_fsbl.log
 if($LASTEXITCODE -ne 0 -or (Get-Content boot_qspi/diagnostics/build_fsbl.log -Raw) -notmatch '(?m)^QSPI_FSBL_READY:'){throw 'QSPI FSBL build failed. See boot_qspi/diagnostics/build_fsbl.log'}
 & (Join-Path $PSScriptRoot 'build_boot.ps1') -VitisBin $VitisBin
} finally {Pop-Location}
