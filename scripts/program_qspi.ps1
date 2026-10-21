param(
    [switch]$Program,
    [switch]$Probe,
    [string]$VitisBin='D:\Xilinx\Install\2025.2\Vitis\bin'
)
$ErrorActionPreference='Stop'
if($Program -and $Probe){throw 'Use either -Probe or -Program, not both.'}
$root=Split-Path -Parent $PSScriptRoot
$out=Join-Path $root 'boot_qspi'
$manifest=Get-Content -LiteralPath (Join-Path $out 'manifest.json') -Raw | ConvertFrom-Json
if($manifest.qspi_fsbl_enabled -ne $true){throw 'Old JTAG-only FSBL package. Run scripts\rebuild_boot.ps1 first.'}
foreach($entry in $manifest.files.PSObject.Properties){
    $p=Join-Path $root $entry.Name
    if(!(Test-Path -LiteralPath $p) -or (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash -ne $entry.Value){throw "Boot package is stale or damaged: $p. Run scripts\build_boot.ps1 again."}
}
$tool=Join-Path $VitisBin 'program_flash.bat'
if(!(Test-Path -LiteralPath $tool)){throw "Missing tool: $tool"}
if(!$Program -and !$Probe){
    Write-Host 'BOOT_PACKAGE_CHECK_OK: no hardware connection or Flash write performed.'
    Write-Host 'Read boot_qspi\README.md first.'
    Write-Host 'Power OFF; core switch 1=ON 2=ON; connect JTAG; power ON.'
    Write-Host 'Use -Probe to identify Flash without erase/program; use -Program to replace the boot image.'
    return
}
if($Probe){
    Write-Host 'QSPI probe: temporarily initializes PS/DDR; no Flash erase or programming.'
} else {
    Write-Host 'Programming QSPI offset 0: existing boot image in the covered sectors will be replaced.'
}
Write-Host 'Disconnect motor VM power; keep board power and JTAG connected until the command completes.'
if(!(Get-Process hw_server -ErrorAction SilentlyContinue)){
    Start-Process -FilePath (Join-Path $VitisBin 'hw_server.bat') -ArgumentList '-s','tcp::3121' -WindowStyle Hidden
    Start-Sleep -Seconds 2
}
$preflight=& (Join-Path $VitisBin 'xsct.bat') (Join-Path $PSScriptRoot 'qspi_preflight.tcl') 2>&1
$code=$LASTEXITCODE
$preflight | Write-Output
if($code -ne 0 -or ($preflight -join "`n") -notmatch '(?m)^QSPI_PREFLIGHT_OK:'){throw 'QSPI preflight failed. Flash was not written. See the error above.'}
$helper=Join-Path (Split-Path -Parent $VitisBin) 'data\xicom\cfgmem\uboot\zynq_qspi_x8_dual_parallel.bin'
if(!(Test-Path -LiteralPath $helper) -or (Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -ne 'ccb5789bbcad9e86f2111eb5b93f3b8aa8b5c861fb3b01a4cb4baca93fad3c54'){
    throw 'Expected bundled 32MB dual-parallel helper is missing/changed; inspect before programming.'
}
$previousHelper=$env:XIL_UBOOT_IMAGE_FILE
$env:XIL_UBOOT_IMAGE_FILE=$helper
Push-Location $out
try {
    # This installed legacy helper embeds 2 x 16MB parallel devices.
    # The 2025.2 automatic selector incorrectly chose *_2048.bin on this Zynq.
    $flashArgs=@('-f','BOOT.BIN','-offset','0','-flash_type','qspi-x8-dual_parallel','-flash_density','32','-fsbl','fsbl.elf','-url','tcp:127.0.0.1:3121')
    if($Probe){
        # A small read/compare forces JEDEC probing without reading the whole boot image.
        $probeData=New-Object byte[] 64
        [Text.Encoding]::ASCII.GetBytes('READ-ONLY QSPI IDENTIFICATION; NOT A BOOT IMAGE').CopyTo($probeData,0)
        [IO.File]::WriteAllBytes((Join-Path $out 'probe_only.bin'),$probeData)
        $flashArgs[1]='probe_only.bin'
        $flashArgs+=@('-no_erase','-no_program');$logName='probe_flash.log'
    }
    else {$flashArgs+=@('-blank_check','-verify');$logName='program_flash.log'}
    if($Probe){& $tool @flashArgs *> $logName}
    else {& $tool @flashArgs 2>&1 | Tee-Object -FilePath $logName}
    $code=$LASTEXITCODE
    $log=Get-Content -LiteralPath $logName -Raw
    if($Probe){
        # -no_program automatically compares the dummy bytes with existing content.
        # A compare mismatch is expected; it is not a programming attempt/failure.
        if($log -notmatch 'SF: Detected n25q128a13.*total 32 MiB' -or
           $log -notmatch 'Read: OK' -or
           $log -notmatch 'Verify Operation (successful|unsuccessful)' -or
           $log -match 'sf (erase|write)|Timeout!|unrecognized JEDEC|initialization failed'){
            throw "Flash identification/read was not confirmed. See boot_qspi\$logName (exit $code)."
        }
        Write-Host 'QSPI_PROBE_OK: n25q128a13 dual parallel, total 32MiB; read OK; no erase/write.'
        Write-Host 'A dummy-image compare mismatch in probe_flash.log is expected. This is not a boot verification.'
    } else {
        if($code -ne 0 -or $log -notmatch 'Flash Operation Successful' -or $log -notmatch 'Verify Operation successful'){throw 'Flash read-back verification was not confirmed.'}
        Write-Host 'QSPI_PROGRAM_OK: power OFF; set core switch 1=ON 2=OFF; disconnect JTAG; power ON; keep quiet about 8 seconds after application starts.'
    }
} finally {Pop-Location;$env:XIL_UBOOT_IMAGE_FILE=$previousHelper}
