param(
    [string]$VivadoBin = 'D:\Xilinx\Install\2025.2\Vivado\bin',
    [switch]$SkipSynthesis,
    [string[]]$Tests=@('tb_mic_i2s_clock','tb_i2s_rx_pair','tb_mic_array_top','tb_mic_capture_control','tb_mic_board_power','tb_mic_axis_packet','tb_mic_soc_stream','tb_servo_pwm')
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RtlDir = Join-Path $ProjectRoot 'SXCX.srcs\sources_1\new'
$SimDir = Join-Path $ProjectRoot 'SXCX.srcs\sim_1\new'
$ReportsDir = Join-Path $ProjectRoot 'reports'
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
$TempParent = [System.IO.Path]::GetFullPath($ReportsDir)
$RunDir = Join-Path $TempParent ('my_fpga_verify_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $RunDir | Out-Null
$PreviousDir = (Get-Location).Path

function Invoke-CheckedTool {
    param([string]$Program, [string[]]$ToolArgs, [string]$LogFile)
    & $Program @ToolArgs 2>&1 | Tee-Object -FilePath $LogFile
    if ($LASTEXITCODE -ne 0) { throw "Tool failed: $Program ($LASTEXITCODE)" }
}

try {
    Set-Location -LiteralPath $RunDir
    $DesignFiles = @('mic_i2s_clock.v','i2s_rx_pair.v','mic_pair_top.v','mic_array_top.v','mic_capture_control.v','mic_board_top.v','mic_axis_packet.v','mic_soc_top.v','car_motor.v','servo_pwm.v') |
        ForEach-Object { Join-Path $RtlDir $_ }
    # Lightweight debug/clock models are ONLY for this standalone regression.
    # They are not added to the Vivado project or used in hardware builds.
    $DesignFiles += Join-Path $PSScriptRoot 'test_support\board_debug_models.v'
    $DesignFiles += Join-Path $PSScriptRoot 'test_support\system_wrapper_stub.v'
    $DesignFiles += Join-Path $PSScriptRoot 'test_support\camera_display_stub.v'
    $VerilogTests = @('tb_mic_i2s_clock.v','tb_i2s_rx_pair.v') |
        ForEach-Object { Join-Path $SimDir $_ }
    Invoke-CheckedTool (Join-Path $VivadoBin 'xvlog.bat') ($DesignFiles + $VerilogTests) (Join-Path $ReportsDir 'compile_verilog.log')
    $SvTests = @('--sv',(Join-Path $SimDir 'i2s_mic_array_model.sv'),(Join-Path $SimDir 'tb_mic_array_top.sv'),(Join-Path $SimDir 'tb_mic_capture_control.sv'))
    $SvTests += Join-Path $PSScriptRoot 'test_support\tb_mic_board_power.sv'
    $SvTests += Join-Path $PSScriptRoot 'test_support\tb_mic_axis_packet.sv'
    $SvTests += Join-Path $PSScriptRoot 'test_support\tb_mic_soc_stream.sv'
    $SvTests += Join-Path $PSScriptRoot 'test_support\tb_servo_pwm.sv'
    Invoke-CheckedTool (Join-Path $VivadoBin 'xvlog.bat') $SvTests (Join-Path $ReportsDir 'compile_testbench.log')
    foreach ($TestTop in $Tests) {
        Invoke-CheckedTool (Join-Path $VivadoBin 'xelab.bat') @("work.$TestTop",'-s',$TestTop,'-debug','typical') (Join-Path $ReportsDir "$TestTop.elaborate.log")
        $TestLog = Join-Path $ReportsDir "$TestTop.log"
        Invoke-CheckedTool (Join-Path $VivadoBin 'xsim.bat') @($TestTop,'-runall') $TestLog
        $ResultText = Get-Content -LiteralPath $TestLog -Raw
        if ($ResultText -notmatch 'PASS:' -or $ResultText -match 'Fatal:|FATAL|ERROR:') {
            throw "Simulation assertions failed: $TestTop"
        }
    }
    if (-not $SkipSynthesis) {
        $SynthLog = Join-Path $ReportsDir 'synthesis_ooc.log'
        $SynthScript = (Join-Path $PSScriptRoot 'synth_ooc.tcl').Replace('\','/')
        Invoke-CheckedTool (Join-Path $VivadoBin 'vivado.bat') @('-mode','batch','-nojournal','-log',(Join-Path $RunDir 'vivado.log'),'-source',$SynthScript) $SynthLog
        $SynthText = Get-Content -LiteralPath $SynthLog -Raw
        if ($SynthText -notmatch 'OOC_SYNTHESIS_OK' -or $SynthText -match 'ERROR:') {
            throw 'OOC synthesis did not finish successfully'
        }
    }
    Write-Output 'ALL_REQUESTED_CHECKS_PASSED'
} finally {
    Set-Location -LiteralPath $PreviousDir
    $ResolvedRun = (Resolve-Path -LiteralPath $RunDir).Path
    $ResolvedParent = Split-Path -Parent $ResolvedRun
    if ($ResolvedParent -eq $TempParent.TrimEnd('\') -and
        (Split-Path -Leaf $ResolvedRun) -match '^my_fpga_verify_[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $ResolvedRun -Recurse -Force
    } else {
        throw "Refusing to remove unexpected temporary path: $ResolvedRun"
    }
}
