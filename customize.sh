ui_print "#############################################"
ui_print "您正在安装的是 ZT_Boosted 子腾系统通用优化模块"
ui_print "模块版本：v1.0-dev"
cat By_No22.txt
ui_print "#############################################"
echo -e "系统版本：$(getprop ro.build.display.id)"
ui_print "- 正在释放文件"
mkdir "/storage/emulated/0/Android/ZT_boost"
ui_print "- 创建 ZT_Boosted 文件夹"
ui_print "- 配置文件与日志位于 /storage/emulated/0/Android/ZT_boost"
unzip -o "$ZIPFILE" 'config.yaml' -d "/storage/emulated/0/Android/ZT_Boosted/" >&2
echo "[$(date '+%m-%d %H:%M:%S.%3N')] ZT_Boosted v1.0-dev 模块安装成功, 等待重启" >> "/storage/emulated/0/Android/ZT_Boosted/config.yaml.log"
ui_print "- ZT_Boosted v1.0-dev 子腾系统通用优化模块"
ui_print "- 对系统 CPU / GPU / 内存深度优化"
ui_print "- 模块可以释放手机的全部性能"
ui_print "- 可自行查看 service.sh 与 system.prop 文件"
ui_print "- 默认不删除温控, 关于打开“删除温控”功能请自行前往酷安查看教程"
ui_print "- 配置文件在 /storage/emulated/0/Android/config.yaml"
ui_print "- 日志文件在 /storage/emulated/0/Android/config.yaml.log"
ui_print "- 作者 QQ: 854675824 | 酷安@TheCheese"
ui_print "- 模块安装结束 重启生效"