param([string]$VitisBin='D:\Xilinx\Install\2025.2\Vitis\bin')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$out=Join-Path $root 'boot_qspi'
New-Item -ItemType Directory -Path $out -Force | Out-Null
# Package the current release; this script never connects to hardware.
$manifest=Get-Content -LiteralPath (Join-Path $root 'soc_hw\build_manifest.json') -Raw | ConvertFrom-Json
foreach($entry in $manifest.PSObject.Properties){
    $p=Join-Path $root $entry.Name
    if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $entry.Value){throw "Release mismatch: $p"}
}
# A JTAG-only FSBL cannot boot from QSPI. Require the separately built QSPI FSBL.
$receiptPath=Join-Path $out 'fsbl_receipt.json'
if(!(Test-Path -LiteralPath $receiptPath)){throw 'QSPI FSBL missing. Run scripts\rebuild_boot.ps1 first.'}
$receipt=Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
foreach($entry in $receipt.PSObject.Properties){
    $p=Join-Path $root $entry.Name
    if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $entry.Value){throw "QSPI FSBL stale: $p. Run scripts\rebuild_boot.ps1."}
}
$fsbl=Join-Path $out 'fsbl.elf'
$bootgen=Join-Path $VitisBin 'bootgen.bat'
if(!(Test-Path -LiteralPath $bootgen)){throw "Missing bootgen: $bootgen"}
$bif=@('the_ROM_image:', '{', '    [bootloader] fsbl.elf', '    ../soc_hw/mic_soc_top.bit', '    ../soc_sdk/workspace/mic_angle/build/mic_angle.elf', '}')
Set-Content -LiteralPath (Join-Path $out 'boot.bif') -Value $bif -Encoding ASCII
Push-Location $out
try {
    $buildLog=& $bootgen -arch zynq -image boot.bif -o BOOT.BIN -w on 2>&1
    $code=$LASTEXITCODE
    $buildLog | Set-Content -LiteralPath 'build.log' -Encoding UTF8
    $buildLog | Write-Output
    if($code -ne 0 -or ! (Test-Path -LiteralPath 'BOOT.BIN')){throw 'BOOT.BIN build failed; see boot_qspi/build.log'}
    $readLog=& $bootgen -arch zynq -read BOOT.BIN 2>&1
    $code=$LASTEXITCODE
    $readLog | Set-Content -LiteralPath 'headers.log' -Encoding UTF8
    if($code -ne 0){throw 'BOOT.BIN header read failed'}
    $inputs=[ordered]@{}
    foreach($rel in @('soc_hw\system_wrapper.xsa','soc_hw\mic_soc_top.bit','soc_sdk\workspace\mic_angle\build\mic_angle.elf','boot_qspi\boot_init.xsa','boot_qspi\fsbl_receipt.json','boot_qspi\ps7_init_qspi.tcl','boot_qspi\fsbl.elf','boot_qspi\boot.bif','boot_qspi\BOOT.BIN')){
        $inputs[$rel.Replace('\','/')]=(Get-FileHash -LiteralPath (Join-Path $root $rel) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    [ordered]@{program='CAR1';built_at=(Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz');architecture='zynq';qspi_fsbl_enabled=$true;flash_type='qspi-x8-dual_parallel';offset='0x0';board_programmed=$false;files=$inputs} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'manifest.json' -Encoding UTF8
    Write-Host 'BOOT_IMAGE_READY: boot_qspi\BOOT.BIN; CAR1 mode 1 on boot; Flash has NOT been programmed.'
} finally {Pop-Location}
