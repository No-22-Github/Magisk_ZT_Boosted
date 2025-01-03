# Magisk_ZT_Boosted v1.0
# 基于 Magisk-All-In-One v1.3
# 延迟执行 service.sh 脚本
# All-In-One v1.0 的 sleep 1m 在某些设备上不太实际
# 从 v1.2 版本开始采用监测文件方案判断是否开机
# while true 嵌套 sleep 1 并不会造成开机卡死
# 参考如何有效降低死循环的 CPU 占用 - sebastia - 博客园
# https://www.cnblogs.com/memoryLost/p/10907654.html

# 循环判断是否开机
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3 # 不急
done
# 创建用于文件权限测试的文件
test_file="/sdcard/Android/.PERMISSION_TEST"
# 写入 true 到文件
true >"$test_file"
# 判断是否有权限
while [ ! -f "$test_file" ]; do
    true > "$test_file"
    sleep 1
done
# 删除测试文件
rm "$test_file"


# 定义配置文件路径和日志文件路径
CONFIG_FILE="/storage/emulated/0/Android/ZT_Boosted/config.yaml"
LOG_FILE="/storage/emulated/0/Android/ZT_Boosted/config.yaml.log"
# 定义 module_log 输出日志函数
module_log() {
  echo "[$(date '+%m-%d %H:%M:%S.%3N')] $1" >> $LOG_FILE
}
# 定义 read_config 读取配置函数，若找不到匹配项，则返回默认值
read_config() {
  result=$(awk -v start="$1" '
    $0 ~ "^" start {
      sub("^" start, "");
      print;
      exit
    }
  ' "$CONFIG_FILE")
  if [ -z "$result" ]; then
    echo "$2"
  else
    echo "$result"
  fi
}


# 读取 config.yaml 配置

# 获取性能模式
# 0: 性能优先
# 1: 省电优先
PERFORMANCE=$(read_config "性能调节 " "0")

# 获取 CPU 应用分配
BACKGROUND=$(read_config "用户后台应用 " "0")
SYSTEM_BACKGROUND=$(read_config "系统后台应用 " "0")
FOREGROUND=$(read_config "前台应用 " "0-3")
SYSTEM_FOREGROUND=$(read_config "上层应用 " "0-3")

# CPU 调度模式 SCALING
CPU_SCALING="performance"

# 其他选项
# TCP 网络优化
OPTIMIZE_TCP=$(read_config "TCP网络优化 " "1")
# 模块日志输出
OPTIMIZE_MODULE=$(read_config "模块日志输出 " "0")
# 无线 ADB 调试
WIRELESS_ADB=$(read_config "无线ADB调试 " "0")

# 调整模块日志输出
if [ "$OPTIMIZE_MODULE" == "0" ]; then
  # 判断日志文件是否为已创建
  # 已创建则在文件末尾添加换行
  [ -f $LOG_FILE ] && echo "" >> $LOG_FILE
else
  LOG_FILE = "/dev/null"
fi

# 输出日志
module_log "开机完成，正在读取 config.yaml 配置..."


# 调节 CPU 激进度百分比%
# 前台的应用（100%会把cpu拉满）
# echo "10" > /dev/stune/foreground/schedtune.boost
# 显示在上层的应用
# echo "0" > /dev/stune/top-app/schedtune.boost
# 用户的后台应用（减少cpu乱跳，省电）
# echo "0" > /dev/stune/background/schedtune.boost


if [ "$PERFORMANCE" == "0" ]; then
  # 设置 CPU 应用分配
  # 用户后台应用
  echo $BACKGROUND > /dev/cpuset/background/cpus
  # 系统后台应用
  echo $SYSTEM_BACKGROUND > /dev/cpuset/system-background/cpus
  # 前台应用
  echo $FOREGROUND > /dev/cpuset/foreground/cpus
  # 上层应用
  echo $SYSTEM_FOREGROUND > /dev/cpuset/top-app/cpus

  module_log "正在设置 CPU 应用分配"
  module_log "- 用户的后台应用: $BACKGROUND"
  module_log "- 系统的后台应用: $SYSTEM_BACKGROUND"
  module_log "- 前台应用: $FOREGROUND"
  module_log "- 上层应用: $SYSTEM_FOREGROUND"

  # 较为轻的温控方案
  # GPU 温控 115度 极限120 到120会过热保护
  echo "115000" > /sys/class/thermal/thermal_zone32/trip_point_0_temp
  # CPU 温控 修改为99度
  echo "99000" > /sys/class/thermal/thermal_zone36/trip_point_0_temp
  module_log "- 核心分配优化已开启"
  module_log "- CPU/GPU 温控优化温控已开启"
  # CPU 调度
  chmod 644 /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
  echo $CPU_SCALING > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
  # 将 CPU_SCALING 模式转换为大写字符串并输出
  CPU_SCALING_UPPERCASE=$(echo "$CPU_SCALING" | tr '[:lower:]' '[:upper:]')
  module_log "CPU 调度模式为 ${CPU_SCALING_UPPERCASE} 性能模式"
fi

# 省电模式
if [ "$PERFORMANCE" == "1" ]; then
  # 设置 CPU 应用分配
  echo "0" > /dev/cpuset/background/cpus
  # 系统后台应用
  echo "0" > /dev/cpuset/system-background/cpus
  # 前台应用
  echo "0-3" > /dev/cpuset/foreground/cpus
  # 上层应用
  echo "2-3" > /dev/cpuset/top-app/cpus
  module_log "省电模式，启动！"
  module_log "正在设置 CPU 应用分配"
  module_log "- 用户的后台应用: 0"
  module_log "- 系统的后台应用: 0"
  module_log "- 前台应用: 0-3"
  module_log "- 上层应用: 2-3"
  
  # CPU 调度
  chmod 644 /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
  echo "sprdemand" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
  module_log "CPU 调度模式为 SPRDEMAND 节电模式"
fi


# 启用 CPU 动态电压调节的功能
echo "1" > /sys/devices/system/cpu/c1dcvs/enable_c1dcvs
if [ "$PERFORMANCE" == "0" ]; then
  # CPU 调整
  echo "100" > /dev/stune/schedtune.boost
  echo "100" > /dev/stune/foreground/schedtune.boost
  echo "100" > /dev/stune/top-app/schedtune.boost
  echo "20" > /dev/stune/background/schedtune.boost
  echo "20" > /dev/stune/rt/schedtune.boost
  echo "50" > /dev/stune/io/schedtune.boost
  echo "50" > /dev/stune/camera-daemon/schedtune.boost
  # 禁用 调度自动分组
  echo "0" > /proc/sys/kernel/sched_autogroup_enabled
  # 功耗换性能
  echo "1" > /sys/module/ged/parameters/gx_game_mode
  echo "47" > /sys/module/ged/parameters/gx_fb_dvfs_margin
  echo "1" > /sys/module/ged/parameters/enable_cpu_boost
  echo "1" > /sys/module/ged/parameters/enable_gpu_boost
  echo "1" > /sys/module/ged/parameters/gx_dfps
  echo "1" > /sys/devices/system/cpu/cpufreq/performance/boost
  echo "1" > /sys/devices/system/cpu/cpufreq/performance/max_freq_hysteresis
  echo "1" > /sys/devices/system/cpu/cpufreq/performance/align_windows
  echo "0" > /sys/module/adreno_idler/parameters/adreno_idler_active
  echo "1" > /sys/module/msm_performance/parameters/touchboost
  echo "-1" > /sys/kernel/fpsgo/fbt/thrm_limit_cpu
  echo "-1" > /sys/kernel/fpsgo/fbt/thrm_sub_cpu
  # CPU 极致优化
  # DDR
  chmod 777 /sys/devices/system/cpu/bus_dcvs/DDR/boost_freq
  echo "4224000" > /sys/devices/system/cpu/bus_dcvs/DDR/boost_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/DDR/boost_freq
  chmod 777 /sys/devices/system/cpu/bus_dcvs/DDR/hw_min_freq
  echo "4224000" > /sys/devices/system/cpu/bus_dcvs/DDR/hw_min_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/DDR/hw_min_freq
  # DDRQOS
  chmod 777 /sys/devices/system/cpu/bus_dcvs/DDRQOS/boost_freq
  echo "1" > /sys/devices/system/cpu/bus_dcvs/DDRQOS/boost_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/DDRQOS/boost_freq
  chmod 777 /sys/devices/system/cpu/bus_dcvs/DDRQOS/hw_min_freq
  echo "1" > /sys/devices/system/cpu/bus_dcvs/DDRQOS/hw_min_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/DDRQOS/hw_min_freq
  # L3
  chmod 777 /sys/devices/system/cpu/bus_dcvs/L3/boost_freq
  echo "1804800" > /sys/devices/system/cpu/bus_dcvs/L3/boost_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/L3/boost_freq
  chmod 777 /sys/devices/system/cpu/bus_dcvs/L3/hw_min_freq
  echo "1804800" > /sys/devices/system/cpu/bus_dcvs/L3/hw_min_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/L3/hw_min_freq
  # LLCC
  chmod 777 /sys/devices/system/cpu/bus_dcvs/LLCC/boost_freq
  echo "1066000" > /sys/devices/system/cpu/bus_dcvs/LLCC/boost_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/LLCC/boost_freq
  chmod 777 /sys/devices/system/cpu/bus_dcvs/LLCC/hw_min_freq
  echo "1066000" > /sys/devices/system/cpu/bus_dcvs/LLCC/hw_min_freq
  chmod 444 /sys/devices/system/cpu/bus_dcvs/LLCC/hw_min_freq
  # 设定当大核忙碌程度hispeed_load到达一定值时立刻跳到设定的freq频率
  chmod 777 /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_load
  echo "30" > /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_load
  chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_load
  # CPU 3
  chmod 777 /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_load
  echo "40" > /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_load
  chmod 777 /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_load
  # CPU 7
  chmod 777 /sys/devices/system/cpu/cpu7/cpufreq/walt/hispeed_load
  echo "55" > /sys/devices/system/cpu/cpu7/cpufreq/walt/hispeed_load
  chmod 777 /sys/devices/system/cpu/cpu7/cpufreq/walt/hispeed_load
  # CPU 0
  # 设定当大核忙碌程度hispeed_load到达一定值时立刻跳到设定的freq频率
  chmod 777 /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_freq
  echo "2016000" > /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_freq
  chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/walt/hispeed_freq
  # CPU 3
  chmod 777 /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_freq
  echo "2803200" > /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_freq
  chmod 777 /sys/devices/system/cpu/cpu3/cpufreq/walt/hispeed_freq
  # CPU
  chmod 777 /sys/devices/system/cpu/cpufreq/policy0/walt/boost
  echo "1" > /sys/devices/system/cpu/cpufreq/policy0/walt/boost
  chmod 444 /sys/devices/system/cpu/cpufreq/policy0/walt/boost
  # Policy 3
  chmod 777 /sys/devices/system/cpu/cpufreq/policy3/walt/boost
  echo "1" > /sys/devices/system/cpu/cpufreq/policy3/walt/boost
  chmod 444 /sys/devices/system/cpu/cpufreq/policy3/walt/boost
  # Policy 7
  chmod 777 /sys/devices/system/cpu/cpufreq/policy7/walt/boost
  echo "1" > /sys/devices/system/cpu/cpufreq/policy7/walt/boost
  chmod 444 /sys/devices/system/cpu/cpufreq/policy7/walt/boost
  # Policy 0
  chmod 777 /sys/devices/system/cpu/cpufreq/policy0/walt/adaptive_high_freq
  echo "1" > /sys/devices/system/cpu/cpufreq/policy0/walt/adaptive_high_freq
  chmod 444 /sys/devices/system/cpu/cpufreq/policy0/walt/adaptive_high_freq
  # Policy 3
  chmod 777 /sys/devices/system/cpu/cpufreq/policy3/walt/adaptive_high_freq
  echo "1" > /sys/devices/system/cpu/cpufreq/policy3/walt/adaptive_high_freq
  chmod 444 /sys/devices/system/cpu/cpufreq/policy3/walt/adaptive_high_freq
  # Policy 7
  chmod 777 /sys/devices/system/cpu/cpufreq/policy7/walt/adaptive_high_freq
  echo "1" > /sys/devices/system/cpu/cpufreq/policy7/walt/adaptive_high_freq
  chmod 444 /sys/devices/system/cpu/cpufreq/policy7/walt/adaptive_high_freq
  # CoreCTL CPU 0
  chmod 777 /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
  echo "0" > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
  chmod 444 /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
  # CoreCTL CPU 3
  chmod 777 /sys/devices/system/cpu/cpu3/core_ctl/offline_delay_ms
  echo "0" > /sys/devices/system/cpu/cpu3/core_ctl/offline_delay_ms
  chmod 444 /sys/devices/system/cpu/cpu3/core_ctl/offline_delay_ms
  # CoreCTL CPU 7
  chmod 777 /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
  echo "0" > /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
  chmod 444 /sys/devices/system/cpu/cpu7/core_ctl/offline_delay_ms
  # CoreCTL CPU 0
  chmod 777 /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
  echo "100 100 100" > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
  chmod 444 /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
  # CoreCTL CPU 3
  chmod 777 /sys/devices/system/cpu/cpu3/core_ctl/busy_up_thres
  echo "100 100 100" > /sys/devices/system/cpu/cpu3/core_ctl/busy_up_thres
  chmod 444 /sys/devices/system/cpu/cpu3/core_ctl/busy_up_thres
  # CoreCTL CPU 7
  chmod 777 /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
  echo "100 100 100" > /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
  chmod 444 /sys/devices/system/cpu/cpu7/core_ctl/busy_up_thres
  # CoreCTL CPU 0
  chmod 777 /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
  echo "20 20 20" > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
  chmod 444 /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
  # CoreCTL CPU 3
  chmod 777 /sys/devices/system/cpu/cpu3/core_ctl/busy_down_thres
  echo "25 25 25" > /sys/devices/system/cpu/cpu3/core_ctl/busy_down_thres
  chmod 444 /sys/devices/system/cpu/cpu3/core_ctl/busy_down_thres
  # CoreCTL CPU 7
  chmod 777 /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
  echo "20 20 20" > /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
  chmod 444 /sys/devices/system/cpu/cpu7/core_ctl/busy_down_thres
  # 设置 GPU 等待时间
  chmod 777 /sys/class/kgsl/kgsl-3d0/idle_timer
  echo "120" > /sys/class/kgsl/kgsl-3d0/idle_timer
  chmod 444 /sys/class/kgsl/kgsl-3d0/idle_timer
  # 关闭 CPU 动态电压调节的功能
  echo 0 > /sys/devices/system/cpu/c1dcvs/enable_c1dcvs
  # 通过DEBUG模式开启 GPU/CPU 加速
  settings put global enable_gpu_debug_layers 0
  settings put system debug.composition.type dyn
  module_log "GPU 加速已开启 (启用DEBUG模式)"
  echo "1" > /proc/cpu_loading/debug_enable
  echo "1" > /proc/cpu_loading/uevent_enable
  echo "68" > /proc/cpu_loading/overThrhld
  echo "45" > /proc/cpu_loading/underThrhld
  echo "68" > /proc/cpu_loading/specify_overThrhld
  echo "7654" > /proc/cpu_loading/specify_cpus
  module_log "CPU 加速已开启（启用DEBUG模式）"
  # GPU 优化
  echo "0" > /sys/class/kgsl/kgsl-3d0/default_pwrlevel
  echo "3" > /sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost
  # ETO 优化
  echo "0" > /sys/module/simple_gpu_algorithm/parameters/simple_laziness
  echo "10000" > /sys/module/simple_gpu_algorithm/parameters/simple_ramp_threshold
  echo "0" > /sys/module/adreno_idler/parameters/adreno_idler_downdifferential
  echo "99" > /sys/module/adreno_idler/parameters/adreno_idler_idlewait
  echo "1000" > /sys/module/adreno_idler/parameters/adreno_idler_idleworkload
fi


# I/O STATS 优化
echo "0" > /sys/block/dm-0/queue/iostats
echo "0" > /sys/block/mmcblk0/queue/iostats
echo "0" > /sys/block/mmcblk0rpmb/queue/iostats
echo "0" > /sys/block/mmcblk1/queue/iostats
echo "0" > /sys/block/loop0/queue/iostats
echo "0" > /sys/block/loop1/queue/iostats
echo "0" > /sys/block/loop2/queue/iostats
echo "0" > /sys/block/loop3/queue/iostats
echo "0" > /sys/block/loop4/queue/iostats
echo "0" > /sys/block/loop5/queue/iostats
echo "0" > /sys/block/loop6/queue/iostats
echo "0" > /sys/block/loop7/queue/iostats
echo "0" > /sys/block/sda/queue/iostats
# 页面簇优化
echo "0" > /proc/sys/vm/page-cluster
# 内核堆优化
echo "0" > /proc/sys/kernel/randomize_va_space
# 禁止压缩不可压缩的进程
echo "0" > /proc/sys/vm/compact_unevictable_allowed

# 关闭 ZRAM 减少性能/磁盘损耗
swapoff /dev/block/zram0 2>/dev/null
swapoff /dev/block/zram1 2>/dev/null
swapoff /dev/block/zram2 2>/dev/null
echo "1" > /sys/block/zram0/reset
module_log "已禁用系统 ZRAM 压缩内存"

# 快充优化
chmod 755 /sys/class/power_supply/*/*
chmod 755 /sys/module/qpnp_smbcharger/*/*
chmod 755 /sys/module/dwc3_msm/*/*
chmod 755 /sys/module/phy_msm_usb/*/*
echo "1" > /sys/kernel/fast_charge/force_fast_charge
echo "1" > /sys/kernel/fast_charge/failsafe
echo "1" > /sys/class/power_supply/battery/allow_hvdcp3
echo "0" > /sys/class/power_supply/battery/restricted_charging
echo "0" > /sys/class/power_supply/battery/system_temp_level
echo "0" > /sys/class/power_supply/battery/input_current_limited
echo "1" >/sys/class/power_supply/battery/subsystem/usb/pd_allowed
echo "1" > /sys/class/power_supply/battery/input_current_settled
echo "100" >/sys/class/power_supply/bms/temp_cool
echo "600" >/sys/class/power_supply/bms/temp_warm
echo "30000" > /sys/module/qpnp_smbcharger/parameters/default_hvdcp_icl_ma
echo "30000" > /sys/module/qpnp_smbcharger/parameters/default_dcp_icl_ma
echo "30000" > /sys/module/qpnp_smbcharger/parameters/default_hvdcp3_icl_ma
echo "30000" > /sys/module/dwc3_msm/parameters/dcp_max_current
echo "30000" > /sys/module/dwc3_msm/parameters/hvdcp_max_current
echo "30000" > /sys/module/phy_msm_usb/parameters/dcp_max_current
echo "30000" > /sys/module/phy_msm_usb/parameters/hvdcp_max_current
echo "30000" > /sys/module/phy_msm_usb/parameters/lpm_disconnect_thresh
echo "30000000" > /sys/class/power_supply/dc/current_max
echo "30000000" > /sys/class/power_supply/main/current_max
echo "30000000" > /sys/class/power_supply/parallel/current_max
echo "30000000" > /sys/class/power_supply/pc_port/current_max
echo "30000000" > /sys/class/power_supply/qpnp-dc/current_max
echo "30000000" > /sys/class/power_supply/battery/current_max
echo "30000000" > /sys/class/power_supply/battery/input_current_max
echo "30000000" > /sys/class/power_supply/usb/current_max
echo "30000000" > /sys/class/power_supply/usb/hw_current_max
echo "30000000" > /sys/class/power_supply/usb/pd_current_max
echo "30000000" > /sys/class/power_supply/usb/ctm_current_max
echo "30000000" > /sys/class/power_supply/usb/sdp_current_max
echo "30100000" > /sys/class/power_supply/main/constant_charge_current_max
echo "30100000" > /sys/class/power_supply/parallel/constant_charge_current_max
echo "30100000" > /sys/class/power_supply/battery/constant_charge_current_max
echo "31000000" > /sys/class/qcom-battery/restricted_current
echo "1" > /sys/class/power_supply/usb/boost_current
module_log "已开启快充优化"

# TCP 优化
if [ "$OPTIMIZE_TCP" == "1" ]; then
  echo "
net.ipv4.conf.all.route_localnet=1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.lo.forwarding = 1
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.accept_ra = 2
net.core.netdev_max_backlog = 100000
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 5000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 67108864
net.core.wmem_default = 67108864
net.core.optmem_max = 65536
net.core.somaxconn = 10000
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.tcp_keepalive_time = 8
net.ipv4.tcp_keepalive_intvl = 8
net.ipv4.tcp_keepalive_probes = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 8
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_syn_backlog = 30000
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_frto = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.neigh.default.gc_thresh1=2048
net.ipv6.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh2=4096
net.ipv6.neigh.default.gc_thresh1=2048
net.ipv4.tcp_max_syn_backlog = 262144
net.netfilter.nf_conntrack_max = 262144
net.nf_conntrack_max = 262144
" > /data/sysctl.conf
  # 给予 sysctl.conf 配置文件权限
  chmod 777 /data/sysctl.conf
  # 启用自定义配置文件
  sysctl -p /data/sysctl.conf
  # 启用 ip route 配置
  ip route | while read config; do
    ip route change $config initcwnd 20;
  done
  # 删除 wlan_logs 网络日志
  rm -rf /data/vendor/wlan_logs
  module_log "已开启 TCP 网络优化"
fi

# Ciallo～ (∠・ω< )⌒☆
module_log "模块 service.sh 已结束"
echo "[$(date '+%m-%d %H:%M:%S.%3N')] Ciallo～ (∠・ω< )⌒☆" >> $LOG_FILE