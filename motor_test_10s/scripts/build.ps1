$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
& "$PSScriptRoot\test.ps1"
Push-Location -LiteralPath $root
try {
 & 'D:\Xilinx\Install\2025.2\Vivado\bin\vivado.bat' -mode batch -nojournal -log reports/vivado.log -source scripts/build.tcl *> reports/build_console.log
 $log=Get-Content -LiteralPath 'reports/build_console.log' -Raw
 if($LASTEXITCODE -or $log -notmatch 'MOTOR_TEST_BUILD_OK' -or $log -match 'CRITICAL WARNING:|ERROR:'){throw 'Motor test build failed; see reports'}
 $manifest=[ordered]@{}
 $files=Get-ChildItem -LiteralPath "$root\rtl","$root\constraints" -File
 $files+=Get-Item -LiteralPath "$root\scripts\build.tcl","$root\output\motor_test_top.bit"
 foreach($f in $files){$name=$f.FullName.Substring($root.Length+1).Replace('\','/');$manifest[$name]=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 $manifest | ConvertTo-Json | Set-Content -LiteralPath output/manifest.json -Encoding UTF8
 Write-Output 'MOTOR_TEST_RELEASE_OK'
} finally {Pop-Location}
