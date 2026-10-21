$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$bin='D:\Xilinx\Install\2025.2\Vitis\bin'
$m=Get-Content -LiteralPath "$root\output\manifest.json" -Raw | ConvertFrom-Json
foreach($e in $m.PSObject.Properties){
 $p=Join-Path $root $e.Name
 if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $e.Value){throw "Test build mismatch: $p; rebuild first"}
}
if(-not (Get-Process hw_server -ErrorAction SilentlyContinue)){
 Start-Process -FilePath "$bin\hw_server.bat" -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
 Start-Sleep -Seconds 2
}
$output=& "$bin\xsct.bat" "$PSScriptRoot\download.tcl"
$output | Write-Output
if($LASTEXITCODE -or ($output -join "`n") -notmatch '(?m)^MOTOR_TEST_READY:'){throw 'Motor test download failed'}
