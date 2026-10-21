$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$bin='D:\Xilinx\Install\2025.2\Vitis\bin'
if(-not (Test-Path -LiteralPath "$taskRoot\soc_hw\debug_symbols.tcl")){throw 'Build the matching ELF first'}
if(-not (Get-Process hw_server -ErrorAction SilentlyContinue)){
 Start-Process -FilePath "$bin\hw_server.bat" -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
 Start-Sleep -Seconds 2
}
$taskOutput=& "$bin\xsct.bat" "$PSScriptRoot\read_status.tcl"
$taskOutput | Write-Output
if($LASTEXITCODE -ne 0 -or ($taskOutput -join "`n") -notmatch '(?m)^STATUS_READ_OK\s*$'){throw 'Cannot read matching JTAG status; inspect the error above'}
