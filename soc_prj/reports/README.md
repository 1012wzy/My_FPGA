# 验证记录说明

本目录保存工具输出、功能测试和板上观测，作为设计报告的依据。记录来自不同开发阶段，不能把所有 PASS、采样值或历史性能数字都当作当前实物验收结论。

| 类别 | 文件或目录 | 用途与边界 |
|---|---|---|
| 硬件实现 | `soc/utilization.rpt`、`soc/timing.rpt`，`zip_camera_build*.log` | 资源、时序及构建依据；以对应硬件版本为准 |
| 软件与行为测试 | `*_host_test.log`、`car_presence_test.log`、`tracking_loop_test.log` | 算法、判决、控制和超时逻辑验证；不是实物定位精度 |
| RTL 仿真 | `tb_*.log`、`*.elaborate.log`、编译日志 | 采集、视频、跨时钟、PWM 与驱动保护验证 |
| 发布与启动包核验 | `CAR1_release_check.log`、`restore18_boot_check.log` | 已有成套文件检查；离线检查不证明 Flash 冷启动成功 |
| 板上运行与采样 | `CAR1_*status*.log`、`CAR1_reload_20261018.log`、`car_*.csv`、`marker_trace*.csv`、`calibration_center.csv` | 保留采样条件和版本后可用于实测分析；原始异常也属于证据 |
| 历史优化对比 | `response_sos2_baseline.log`、`response_*trace*.csv`、`response_*status*.log`、`trajectory_pd_*`、`T800_*status*.log` | 对比旧版行为及历史性能，不能冒充当前配置；PD 阶段记录不表示当前舵机使用 PD |

报告常用文件的来源和内容哈希见 [证据索引](../../report/evidence/README.md)。测试源码在 `soc_sdk/tests`、`soc_prj/SXCX.srcs/sim_1` 和 `soc_prj/scripts/test_support`，运行入口见根目录 README。

Flash 的识别、烧录及诊断记录位于 `boot_qspi`，与本目录的离线包核验分开保存。
