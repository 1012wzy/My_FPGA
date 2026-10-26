# 发布校验数据

- `release_baselines.json`：已验证源码和关键代码段的校验值，运行检查无需历史压缩包。
- `build_recipe_portability.json`：构建脚本末尾 Python 路径的修正记录。原硬件清单保留生成时的哈希；`scripts/hardware_receipt.py` 同时核对修正记录及其余硬件输入。

路径修正只将本机临时解释器改为 Vivado 2025.2 安装目录中的 Python 3.13.0，不改变综合、实现命令或设计输入。该修正不代表重新构建硬件，现有 bit、XSA、ELF 和 BOOT.BIN 保持原内容。今后完整重建成功后，`record_hardware.py` 会重新记录当次构建输入。
