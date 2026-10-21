# OV5640 寄存器来源与当前配置

## 来源

`soc_sdk/src/camera_regs.h` 基于米联客 `ui5640reg.v`，原文件注明 2019/12/17、copyright msxbo。厂商资料相对位置为：

`MLK_H3_CZ08-7100/03_soc_demo/3_3_ex_image_fpga/3_3_1_fpga_img_H3_CZ08_7100FC/02_ov5640/soc_prj/fpga_prj.ip_user_files/bd/system/ipshared/ab0c/ui5640reg.v`

原参考文件 SHA-256：`bd200aca691f916dd9ac84d1a896c4efc22abb4f61091b007714018eb5190ec4`。来源归属保留在代码注释中。

寄存器解释参考 [OV5640 数据手册](https://cdn.sparkfun.com/datasheets/Sensors/LightImaging/OV5640_datasheet.pdf) 与 [Linux OV5640 驱动](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5640.c)。工程修改后的配置以随包源码和回读检查为准。

## 当前实现

- RGB565 输入 800×450，尺寸寄存器 0x3808～0x380B 为 03、20、01、C2。
- 0x5001 为 A3，包含 ISP 缩放配置；PL 帧缓存读取同时完成 180°方向校正。
- 三帧片上缓存；HDMI 显示为 1280×720。显示分辨率不能当作摄像头原始采集分辨率或实测帧率。
- 摄像头回读逻辑见 `soc_sdk/src/camera.c`，引脚与时序预算见 `camera_display.xdc`；验证结果见 `soc_prj/reports/zip_camera_host_test.log`、`tb_camera_display.log` 和 `soc/timing.rpt`。
- 画面投影仍依赖镜头视场角、安装位置及标定；寄存器来源和仿真通过不构成实物定位精度证明。
