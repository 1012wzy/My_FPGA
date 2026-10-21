param([string]$VitisBin='D:\Xilinx\Install\2025.2\Vitis\bin')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$manifestPath=Join-Path $root 'soc_hw\build_manifest.json'
if(-not (Test-Path -LiteralPath $manifestPath)){throw 'Missing build_manifest.json. Run build_vitis.py first.'}
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
foreach($entry in $manifest.PSObject.Properties){
    $artifact=Join-Path $root $entry.Name
    if(-not (Test-Path -LiteralPath $artifact) -or (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash -ne $entry.Value){
        throw "Build artifacts do not match: $artifact. Rebuild hardware/software before launch."
    }
}
if (-not (Get-Process hw_server -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath (Join-Path $VitisBin 'hw_server.bat') -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
    Start-Sleep -Seconds 2
}
$taskOutput=& (Join-Path $VitisBin 'xsct.bat') (Join-Path $PSScriptRoot 'run_jtag.tcl')
$taskOutput | Write-Output
if($LASTEXITCODE -ne 0 -or ($taskOutput -join "`n") -notmatch '(?m)^RUNNING:'){throw 'JTAG launch failed. Check target power, JTAG cable and error above.'}
