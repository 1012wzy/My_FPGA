param([ValidateSet(0,1)][int]$Hold=1)
$ErrorActionPreference='Stop'
$bin='D:\Xilinx\Install\2025.2\Vitis\bin'
if(-not (Get-Process hw_server -ErrorAction SilentlyContinue)){
 Start-Process -FilePath "$bin\hw_server.bat" -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
 Start-Sleep -Seconds 2
}
$output=& "$bin\xsct.bat" "$PSScriptRoot\set_marker_hold.tcl" $Hold
$output | Write-Output
if($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch '(?m)^MARKER_HOLD_REQUESTED:'){throw 'Hold request failed'}
