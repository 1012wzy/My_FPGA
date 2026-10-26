# 环境准备与完整复现

## 环境与文件
采用Windows、AMD Vivado/Vitis 2025.2，安装Zynq-7000与xc7z100器件支持、Cortex-A9裸机工具链及USB/JTAG驱动。脚本默认工具根为`D:\Xilinx\Install\2025.2`。本工程提供RTL、约束、BD、PS源码、现成bit/XSA/ELF及QSPI启动镜像；下载现成文件无需先重新综合。

将工程解压到`D:\Xilinx\project\My_FPGA`。更换安装位置时先核对脚本中的工具路径。工程原有Vivado/Vitis管理名称保留，避免只改大小写造成引用、校验清单和工具配置不一致。

## 供电与JTAG临时运行
按[接线表](board_wiring.md)接线。麦克风由J3第1脚供3.3 V；摄像头及TB6612逻辑端由独立稳压3.3 V供电，全部共地。首次检查断开TB6612 VM、架空车轮并留出云台空间。

主板断电，将核心板启动拨码设为1=ON、2=ON；接好主板电源和JTAG后上电。PowerShell执行：
```powershell
Set-Location 'D:\Xilinx\project\My_FPGA'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_jtag.ps1
```
出现`RUNNING:`后安静等待约8秒，完成回中与背景采样。先在模式1观察HDMI更新、连续人声出现SOS及云台跟随；停止声音后标记应撤销。模式1车轮禁用。

确认轮子极性后接通VM，短按并松开BUT1进入模式2。水平轴回中并稳定后，两轮根据可信方位边走边转；约10°内等目标占空比、50°以上差速饱和。最后新可信观测满1200 ms后撤销驱动。该期限是命令撤销时刻，车辆实际停稳另受惯性影响。再次按键回模式1。

## 读取与记录
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\read_status.ps1
```
核对`STATUS_READ_OK`、故障状态、采集块数和视频帧数持续增长，并区分可信新观测与显示保持。采集故障或PL失效保护时不得用屏幕残留标记当作持续声源。定位及车辆运行不依赖PC持续连接。

## 从源码重建
修改RTL、引脚或BD后，先关闭该工程的Vivado/Vitis编辑与调试会话，再运行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rebuild_all.ps1
```
该步骤生成新的配套硬件及PS应用。仅修改`soc_sdk/src`中的软件时运行：
```powershell
& 'D:\Xilinx\Install\2025.2\Vitis\bin\vitis.bat' -s scripts/build_vitis.py
```
以`VITIS_BUILD_OK`及退出码为依据。若迁移目录后工作区仍引用旧路径，可先将`soc_sdk/workspace`移出工程留存，再运行软件构建脚本创建干净工作区；重建后不可混用留存的旧ELF。

## 离线验证
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\soc_prj\scripts\verify.ps1 -SkipSynthesis
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_camera.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_camera_host.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_tracking.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_car.ps1
& 'D:\Xilinx\Install\2025.2\tps\win64\python-3.13.0\python.exe' .\scripts\check_release.py
& 'D:\Xilinx\Install\2025.2\tps\win64\python-3.13.0\python.exe' .\scripts\check_boot_init.py
```
模块测试、产物一致性和实物验收分别记录。发布清单通过说明文件配套，不等于已经重新综合或冷启动测试。

## QSPI重建与独立启动
软件更新后需重新打包：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build_boot.ps1
```
仅PS应用变化且XSA及专用FSBL清单仍匹配时，使用上述build_boot.ps1。运行过rebuild_all.ps1、XSA发生变化或PS初始化改变后，应运行scripts/rebuild_boot.ps1重建配套引导平台、专用FSBL及镜像；build_boot.ps1提示FSBL清单过期时也按此处理。无参数执行scripts/program_qspi.ps1仅核对本地启动包。

确需写入Flash时，断开VM，核心板保持JTAG拨码，上电并连接JTAG，执行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\program_qspi.ps1 -Program
```
此步骤覆盖Flash镜像，等待`QSPI_PROGRAM_OK`后断电，把核心板设为1=ON、2=OFF，拔下JTAG再上电。安静等待背景校准，按模式1和模式2验收。完整说明见[启动包说明](../boot_qspi/README.md)。
