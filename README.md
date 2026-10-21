# 基于 Zynq 的灾害救援系统

**Zynq-Based Disaster Rescue System**

公开仓库 / Repository: [wangzeyang1012/My_FPGA](https://github.com/wangzeyang1012/My_FPGA)

本项目集成七路麦克风阵列、双轴云台、OV5640 摄像头与移动小车，通过
FPGA 音视频采集及 ARM 声源方位估计，实现云台跟踪、HDMI SOS 标记和
小车声源跟随。

A Zynq XC7Z100 system combining a seven-channel microphone array, a two-axis
pan–tilt unit, an OV5640 camera, and a mobile robot. FPGA logic handles audio
acquisition, video display, and PWM output; bare-metal ARM software estimates
sound-source direction using GCC-PHAT cross-correlation and spatial search.
The system supports stationary acoustic tracking and mobile sound-source
following, with SOS overlays and direction visualization over HDMI.

原创部分采用 [MIT License](LICENSE)。第三方代码、IP 和硬件参考资料保留
各自条款，见 [第三方资料说明](THIRD_PARTY_NOTICES.md)。Git 仓库排除可再生成的
Vivado 缓存、实现目录与 Vitis 临时构建文件，保留配套 bit/XSA/ELF、启动包和
验证记录；首次修改硬件后按下文重建。

AMD 自主选题高级组。工程平台为 MLK-H3 / CZ08，器件 XC7Z100FFG900-2，开发工具为 Vivado 2025.2、Vitis 2025.2，PS 采用裸机程序。

## 功能与版本

- 模式 1：七路麦克风定位、双轴云台跟踪、OV5640 视频、HDMI 上的 SOS 标记和右下方向窗口。车轮关闭。
- 模式 2：BUT1 短按松开后进入，左右舵机保持 1500 μs，俯仰舵机继续跟踪；小车根据同一声源判断边走边转。再次按 BUT1 返回模式 1。
- 短暂失声保持时间为 1200 ms，旧采样年龄限制仍为 500 ms。
- 小车基础占空比 64/256，最大单侧差速 38/256，死区 10°，满转角 50°。这是开环 PWM，不代表实际车速；
- 摄像头输入为 800×450 RGB565，HDMI 输出为 1280×720；采用片上三帧缓存，输入并非原生 720p。

## 文件入口与目录对照

| 提交类别 | 本工程位置 | 用途 |
|---|---|---|
| RTL 源码 | soc_prj/SXCX.srcs/sources_1/new | 麦克风、数据流、视频、叠加、舵机和电机逻辑 |
| 约束与系统设计 | soc_prj/SXCX.srcs/constrs_1/new、soc_prj/SXCX.srcs/sources_1/bd | 引脚、时序、PS 与 AXI 系统 |
| Vivado 工程 | soc_prj/SXCX.xpr | 打开硬件工程；生成目录可重建，配套硬件产物见 soc_hw |
| PS 软件 | soc_sdk/src | 定位、背景判定、标记、云台和小车控制；维护此处源码 |
| Vitis 工程 | soc_sdk/workspace | 平台、驱动、导入副本及编译后的 ELF |
| 仿真与验证 | soc_prj/SXCX.srcs/sim_1、soc_sdk/tests、soc_prj/reports | 测试源码、原始结果、资源与时序报告 |
| 构建与运行 | scripts、soc_prj/scripts | 重建、检查、下载及状态读取 |
| 配套硬件产物 | soc_hw | bit、XSA、PS 初始化及一致性清单 |
| 固化包 | boot_qspi | BOOT.BIN、QSPI 专用 FSBL、启动清单和日志 |
| 硬件资料 | docs/reference | 接口原理图、安装图与第三方资料来源 |
| 发布校验数据 | scripts/validation | 源码及关键代码段校验值，无需历史压缩包 |
| 独立电机验证 | motor_test_10s | 前后各 10 秒循环测试，不是主系统入口 |
| 协作与验证索引 | report | 协作记录、报告证据索引；设计报告作为独立文档提交 |
| 可复用技能包 | skill | 排查、接口验证、构建与冷启动工作流 |

本工程采用上述目录组织，与指南推荐的 src/sim/build/board/data 分类对应。Vivado/Vitis 管理的原工程名称保持现状；如制作严格小写命名的提交副本，应同步工程引用并重新验证，不能只批量改名。

## 上板运行

先按 [接线表](docs/board_wiring.md) 核对接口。首次测试架空车轮、断开电机 VM，并留出云台回中空间。主板接好电源和 JTAG；需要设置 JTAG 启动模式时，先断电，将核心板两位拨码设为 1=ON、2=ON，再上电。

在 PowerShell 执行：

```powershell
Set-Location 'D:\Xilinx\project\My_FPGA'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_jtag.ps1
```

出现 `RUNNING:` 后保持安静约 8 秒，等待背景校准。默认模式 1；确认显示和定位后，再接通 VM、短按并松开 BUT1 验证模式 2。BUT1 是用户按键，不是 PS_SRST 或启动拨码。LED1 表示模式 2，LED2 表示电机驱动使能。

模式 2 先等待左右舵机中位指令稳定，再接受有效声源驱动车轮；停止播放后，最后一次有效观测满 1200 ms 撤销驱动，实际车辆仍有惯性。测试用连续人声；单一 1 kHz 正弦波不适合声源判决验收。状态读取：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\read_status.ps1
```

JTAG 下载断电后失效。脱离电脑上电启动见 [QSPI 操作](boot_qspi/README.md)。独立检查轮子见 [电机测试](motor_test_10s/README.md)。

## 重建与验证

工具默认安装在 `D:\Xilinx\Install\2025.2`。更换电脑时应核对脚本中的工具路径及器件支持包。硬件与软件必须配套，不能混用旧 bit 和新 ELF。

```powershell
# 修改 RTL、引脚或系统设计后重建 PL 和 PS
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\rebuild_all.ps1
# 仅修改 PS 源码后
& 'D:\Xilinx\Install\2025.2\Vitis\bin\vitis.bat' -s scripts/build_vitis.py
# 小车模型与 RTL 验证
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test_car.ps1
# 使用安装有标准库的 Python 3 核对现有成套产物
python .\scripts\check_release.py
python .\scripts\check_boot_init.py
```

其他验证入口为 `test_camera.ps1`、`test_camera_host.ps1`、`test_marker.ps1`、`test_response.ps1`、`test_tracking.ps1`。检查现有产物不等于重新综合或新的实物测试。修改应用并准备固化时，还须重新运行 `scripts/build_boot.ps1` 打包；修改 PS 硬件初始化时使用 `scripts/rebuild_boot.ps1` 重建专用引导平台。

## 报告与工程包的分工

设计报告作为独立文档提交，工程包提供配套源码、工程配置、复现步骤和验证证据。两类材料按提交平台要求分别上传或统一打包。

以下依据 AMD 选题指南第 3.3.5.1～3.3.5.4 节（印刷页 21～22，PDF 第 24～25 页）。报告负责解释设计与结论，工程包提供可复现的实现和证据，同类材料可能两边都需要。

| 材料 | 设计报告内容 | 工程包材料 |
|---|---|---|
| 背景、创新与同类对比 | 应用背景、目标、创新点及已有工作对比 | 对应实现源码与第三方来源说明 |
| 系统与软硬件划分 | 原理框图、PL/PS 分工理由、接口及数据流 | `soc_prj` 中 RTL、系统设计、约束；`soc_sdk/src` 中 PS 源码 |
| 算法与控制 | 定位、声源判断、SOS 投影、舵机和差速控制原理及关键参数 | 完整源码、配置和接口定义，不用把全部代码贴进报告 |
| 优化与性能 | 改动依据、前后对比、资源/时序/性能及适用条件 | `soc_prj/reports` 原始工具报告、测试日志和对比记录 |
| 实测与验证 | 测试装置、步骤、条件、统计结果、误差和局限 | 仿真/主机测试源码、CSV、板上输出；证据索引见 `report/evidence` |
| 复现与上板 | 环境、关键操作、验收步骤 | 本 README、`docs/board_wiring.md`、构建/下载脚本、`soc_hw`、`boot_qspi` |
| AI 协作 | 主要提示词、回答、人工纠错与采用依据 | `report/collaboration_record.md` 索引，以及待补的完整对话导出 |
| 可复用 Skill | 提炼过程、验证效果、适用范围与失效条件 | `skill/README.md` 和 `skill/workflows.md` |
| 硬件图与来源 | 必要实物图、接线图、参考文献 | `docs/reference` 中硬件资料及来源，保留第三方版权/许可信息 |

`report/` 提供协作记录和验证证据索引。接线、构建和运行说明用于工程复现。照片、实测数据及完整协作记录的待补项见 [材料说明](report/README.md)；日志用途与版本适用范围见 [验证记录说明](soc_prj/reports/README.md)。
