# 舵机接口核对依据

- [扩展板原理图](../cepx3_schematic.png)：米联客 FEP_GPIO_CEPX3_CARD_20220104 第 1 页。J3/CEP2 第 11、12 脚为 CEP2_3P/N，连接 U1A A17/A18。
- [主板 FEP 原理图](h3_fep.png)：米联客 MLK-H3 VER20240320 第 14 页，U45A A17/A18 连接 BANK12 AD30/AE30。
- 摘图仅用于确认数字信号路径。TBSK15 的供电与机械行程应按实物核对，不能从扩展板原理图推定。

最终接线与 PWM 范围见 [接线表](../../board_wiring.md)。
