# Third-party materials / 第三方资料说明

The root MIT license applies to original contributions by the My_FPGA authors.
It does not replace third-party copyright notices, licenses, or vendor terms.
Redistribution and use of third-party material remain subject to its original
terms. Inclusion here does not grant additional rights to vendor IP or tools.

根目录 MIT 许可证适用于本项目作者的原创贡献，不替代第三方版权声明、
许可证或厂商使用条款。第三方资料仍按其原有条款使用；本仓库不额外授予
厂商 IP 或开发工具的使用权。修改和再分发时应保留原文件中的声明。

| Material | Location and attribution |
| --- | --- |
| AMD/Xilinx platform drivers, standalone BSP, FSBL and generated hardware configuration | `soc_sdk/workspace`, `soc_hw`, `boot_qspi` and Vivado system/IP configuration. Preserve each file's AMD/Xilinx or other upstream notices. Vivado/Vitis and vendor IP are separate dependencies. |
| MLK-H3/CZ08 PS preset | `soc_prj/scripts/vendor_ps_preset.tcl`; source identified in its file header. |
| OV5640 register initialization table | `soc_sdk/src/camera_regs.h` and its Vitis source copy; derived from MLK `ui5640reg.v`, dated 2019-12-17, copyright msxbo. See [register source details](docs/reference/camera/register_source.md). |
| Board/module schematics and assembly reference images | `docs/reference`; supplied as attributed hardware reference material, outside the project's MIT grant. See the [reference index](docs/reference/README.md). |

Generated build caches are omitted from Git. Matching release artifacts and
verification records are retained for reproduction. Their presence does not
change the licenses of embedded third-party components.
