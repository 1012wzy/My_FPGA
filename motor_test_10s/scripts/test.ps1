$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$bin='D:\Xilinx\Install\2025.2\Vivado\bin'
$run=Join-Path $root 'simulation_work'
New-Item -ItemType Directory -Path $run -Force | Out-Null
Push-Location -LiteralPath $run
try {
 & "$bin\xvlog.bat" --sv "$root\rtl\motor_cycle.v" "$root\sim\tb_motor_cycle.sv" *> "$root\reports\compile.log"
 if($LASTEXITCODE){throw 'Test compile failed'}
 & "$bin\xelab.bat" work.tb_motor_cycle -s tb_motor_cycle -debug typical *> "$root\reports\elaborate.log"
 if($LASTEXITCODE){throw 'Test elaboration failed'}
 & "$bin\xsim.bat" tb_motor_cycle -runall *> "$root\reports\simulation.log"
 $log=Get-Content -LiteralPath "$root\reports\simulation.log" -Raw
 if($LASTEXITCODE -or $log -notmatch 'PASS:' -or $log -match 'Fatal:|FATAL|ERROR:'){throw 'Motor sequence simulation failed'}
 Write-Output 'MOTOR_SEQUENCE_TEST_OK'
} finally {Pop-Location}
