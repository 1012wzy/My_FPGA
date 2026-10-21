# QSPI 独立启动包

本目录保存主系统的 BOOT.BIN、QSPI 专用 fsbl.elf、boot_init.xsa、初始化文件、分区配置、哈希清单和编程日志。BOOT.BIN 包含 FSBL、PL bit 和 PS 应用；JTAG 临时下载不会更新 Flash。

## 校验与写入

在工程根目录执行无参数命令，仅校验本地文件，不连接主板：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\program_qspi.ps1
```

需要固化时：断开电机 VM；主板断电，将核心板两位拨码置 1=ON、2=ON，接好 JTAG 再上电。执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\program_qspi.ps1 -Program
```

此操作覆盖 Flash 偏移 0 开始的镜像扇区。期间保持主板电源与 JTAG 连接。须出现写后校验成功和 `QSPI_PROGRAM_OK`，不能仅凭 BOOT.BIN 文件存在判定已固化。

随后给主板断电，将核心板拨码改为 **1=ON、2=OFF**，拔掉 JTAG 再上电。程序进入模式 1，安静约 8 秒等待背景校准，再按 BUT1 选择模式。更改拨码须断电，拨码设置用于本板具体启动连接。

## 重建与诊断

- `scripts/build_boot.ps1`：用现有专用 FSBL 与最新 bit、ELF 重新打包；修改 PS 应用后需要运行。
- `scripts/rebuild_boot.ps1`：重新生成 QSPI 引导平台、FSBL 和镜像；构建过程中生成 init_hw 和 workspace 工作目录。
- `scripts/check_boot_init.py`：离线核对启动初始化仅增加所需 QSPI 配置。
- `program_qspi.ps1 -Probe`：临时初始化 PS 并只读识别 Flash，不擦写；会影响正在运行的应用。probe_only.bin 为只读比对占位，不是启动镜像。
- 脚本使用匹配本板双并联 32 MiB 的工具内置辅助程序，并核对其哈希；不能改用原 JTAG-only 平台的 FSBL。

编程日志记录对应操作的结果，须结合镜像哈希和版本清单确认其适用范围。历史编程成功记录不能替代当前镜像的断电冷启动验收。
