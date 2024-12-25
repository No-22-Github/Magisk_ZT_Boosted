# ZT-Boosted 子腾系安卓手表通用优化模块
基于：https://github.com/JustLikeCheese/Magisk_All-In-One
精简了原作代码，修改并适配手表，且免配置（大部分情况下）

## 模块特色 / Feature
- 关闭子腾系的安装限制（已测试机型：CD100）
- 触摸屏优化 (提高全局触摸屏响应、提高滚动反映、开启硬件加速)
- 画面显示优化 (解锁 FPS 限制、减少缓冲区数量、开启垂直同步)
- 系统优化 (关闭内核日志、关闭蓝牙日志、优化 SDCard 性能、优化网络性能、默认关闭定位、禁用没啥用的 WPA 调试)
- SQLite 优化 (关闭 SQLite 日志、关闭 Wal SQLite 同步模式)
- CPU 优化 (后台应用 CPU 调控、优化 CPU 温控、优化 CPU 速度)
- GPU 优化 (开启 GPU 加速功能、优化 GPU 温控)
- 内存优化 (默认关闭 ZRAM、优化内存回收)
- TCP 网络优化