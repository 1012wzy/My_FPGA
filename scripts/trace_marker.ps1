$ErrorActionPreference='Stop'
$taskRoot=Split-Path -Parent $PSScriptRoot
$bin='D:\Xilinx\Install\2025.2\Vitis\bin'
if(-not (Get-Process hw_server -ErrorAction SilentlyContinue)){
 Start-Process -FilePath "$bin\hw_server.bat" -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
 Start-Sleep -Seconds 2
}
$taskOutput=& "$bin\xsct.bat" "$PSScriptRoot\trace_marker.tcl"
$taskOutput | Write-Output
if($LASTEXITCODE -ne 0 -or ($taskOutput -join "`n") -notmatch '(?m)^MARKER_TRACE_OK\s*$'){throw 'Marker trace failed'}
Write-Output "Saved $taskRoot\soc_prj\reports\marker_trace.csv"
