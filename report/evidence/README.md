# 证据索引

原始日志位于工程根目录下的 `soc_prj/reports`。`index.json` 的 `source` 为相对工程根目录的路径，`sha256` 用于核对报告引用记录的文件内容。

| 原始文件 | 类型 | 支撑的报告内容 |
|---|---|---|
| [utilization.rpt](../../soc_prj/reports/soc/utilization.rpt) | 综合/实现工具报告 | 资源占用与实现结果 |
| [timing.rpt](../../soc_prj/reports/soc/timing.rpt) | 实现工具报告 | 时序约束与收敛情况 |
| [car_host_test.log](../../soc_prj/reports/car_host_test.log) | 主机软件测试 | 差速、死区、饱和和失声保持逻辑 |
| [car_presence_test.log](../../soc_prj/reports/car_presence_test.log) | 主机软件测试 | 声源有效性与小车启停逻辑 |
| [sound_marker_host_test.log](../../soc_prj/reports/sound_marker_host_test.log) | 主机软件测试 | 声源标记算法与轨迹处理 |
| [tb_car_motor.log](../../soc_prj/reports/tb_car_motor.log) | RTL 仿真 | 电机 PWM 与方向接口 |
| [tb_servo_car.log](../../soc_prj/reports/tb_servo_car.log) | RTL 仿真 | 模式切换与舵机/小车互锁 |
| [tb_car_lease.log](../../soc_prj/reports/tb_car_lease.log) | RTL 仿真 | 电机指令有效期与超时处理 |
| [restore18_boot_check.log](../../soc_prj/reports/restore18_boot_check.log) | 离线包检查 | 启动包与配套产物一致性 |

主机测试、RTL 仿真和离线包检查不等于实际定位精度、车辆性能或断电冷启动验收。实测结论须结合原始板上记录、测试条件和统计。本索引建立已有记录的文件对应关系，不构成独立的上板测试结果。

重新构建或运行测试可能更新同名日志；引用新结果前，应核对版本、更新报告中的数字并重新计算索引哈希，不能将旧结果直接标为新版本结果。
