# 硬件参考资料

本目录保存接口核对、安装和寄存器来源资料。原理图摘图来自板卡及模块资料，引用关系保留；它们不代表本队原创硬件设计。

| 资料 | 用途与来源 |
|---|---|
| [cepx3_schematic.png](cepx3_schematic.png) | 米联客 FEP_GPIO_CEPX3_CARD_20220104 扩展接口原理图；供舵机与 TB6612 接口核对共用 |
| [servo/h3_fep.png](servo/h3_fep.png) | MLK-H3 VER20240320 原理图第 14 页的 FEP 与 BANK12 映射 |
| [car/h3_buttons.png](car/h3_buttons.png) | 主板用户按键与 LED 接口 |
| [mic_array_schematic.png](mic_array_schematic.png) | 麦克风阵列电源与数字接口原理图 |
| [mic_array_assembly.png](mic_array_assembly.png) | 阵列器件位置和接口丝印参考 |
| [camera/cepx3_schematic.png](camera/cepx3_schematic.png) | 摄像头所用扩展接口参考 |
| [camera/hdmi_schematic.png](camera/hdmi_schematic.png) | 主板 HDMI 输出连接依据 |
| [camera/pin_mapping.json](camera/pin_mapping.json) | 摄像头与 HDMI 球脚映射，供工程检查脚本读取 |
| [camera/register_source.md](camera/register_source.md) | 摄像头寄存器表来源与当前配置 |
| boot_qspi/ | 核心板启动、QSPI 连接、SD MIO 及厂家启动资料摘图 |

最终外部接线以 [board_wiring.md](../board_wiring.md) 和工程 XDC 为准。原理图不能代替实物针号与电压核对。PS 初始化参数的来源保留在 `soc_prj/scripts/vendor_ps_preset.tcl` 文件头，工程使用的实际配置见 system.bd。

可复现验证的数据位于 `scripts/validation/release_baselines.json`，包含固定源码、关键代码段校验值及其来源标识；检查工程不需要历史版本压缩包。
