# 独立电机前后循环验证

本工程仅使用 PL 检查 TB6612、供电和两轮极性，不运行声源定位与 HDMI。接线与主工程一致，见 [接线表](../docs/board_wiring.md)。主系统仍由根目录 scripts/run_jtag.ps1 启动。

## 操作

1. 架空两轮、留出空间，先断开 VM。主板上电并连接 JTAG；舵机独立电源可关闭并保留共地。
2. 在主工程根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\motor_test_10s\scripts\download.ps1
```

3. 出现 `MOTOR_TEST_READY` 后，确认供电与极性核对条件，接通 VM；此时默认停止。
4. 短按 BUT1 并松开开始：前进 10 秒 → 高阻滑行间隔 1 秒 → 后退 10 秒 → 间隔 1 秒，循环执行。再次短按停止，必要时断开 VM。
5. 默认 PWM 为 20 kHz、25%占空比；换向前应已停稳。占空比不是轮速，也不能替代电流限制。

LED1 表示循环已启动，LED2 表示后退阶段；与主系统 LED2 的含义不同。实际前进方向由电机安装及两线极性决定。

## 源码与重建

- rtl/：时序、消抖、PWM 和主板顶层。
- constraints/：引脚约束。
- sim/：循环、换向、PWM、停止和复位仿真。
- scripts/build.ps1：仿真后综合实现，生成 output/motor_test_top.bit 与 manifest.json；会重新生成 vivado_project。
- scripts/test.ps1：单独运行仿真，会重新生成 simulation_work。
- reports/：验证、DRC、资源与时序结果。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\motor_test_10s\scripts\build.ps1
```

恢复主系统：先停轮并断 VM，再运行根目录 `scripts/run_jtag.ps1`。测试下载只替换当前易失 PL 配置；它不是主系统固化包。
