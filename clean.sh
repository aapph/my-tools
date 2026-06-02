# 1. 强杀所有正在运行的协议和隧道进程
pkill -f sing-box 2>/dev/null
pkill -f cloudflared 2>/dev/null
pkill -f xray 2>/dev/null
pkill -f hysteria 2>/dev/null

# 2. 彻底停止并卸载系统守护服务 (Systemd)
systemctl stop sing-box cloudflared 2>/dev/null
systemctl disable sing-box cloudflared 2>/dev/null

# 3. 物理粉碎所有服务注册文件
rm -f /etc/systemd/system/sing-box.service
rm -f /lib/systemd/system/sing-box.service
rm -f /etc/systemd/system/cloudflared.service
systemctl daemon-reload

# 4. 彻底斩草除根：粉碎核心程序、配置文件、证书和日志
rm -rf /etc/sing-box /etc/cloudflared
rm -f /usr/local/bin/sing-box
rm -f /usr/local/bin/cloudflared
rm -f /tmp/argo.log

# 5. 清理本地可能残留的安装脚本历史文件
rm -f install_*.sh clean_*.sh

# 6. 重置本地网络栈防火墙规则
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

clear
echo -e "\033[0;31m=================================================="
echo -e "   🧹 报告长官：核心程序 + 配置文件 + 隧道服务      "
echo -e "         已全部物理粉碎，洗地完毕！                "
echo -e "==================================================\033[0m"
