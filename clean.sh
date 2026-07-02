#!/bin/bash
clear
echo -e "\033[0;33m=================================================="
echo -e "   🧹 完全体卸载器 · 七协议矩阵深度清理模式       "
echo -e "==================================================\033[0m"
echo -e "\033[0;31m⚠️  警告：此操作将永久删除所有节点配置、证书和隧道服务，不可恢复！\033[0m"
read -p "👉 确认卸载请输入 YES（其他任意键取消）: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo -e "\033[0;36m👋 已取消，安全退出。\033[0m"
    exit 0
fi

echo -e "\033[0;33m[1/6] 强杀所有协议和隧道进程...\033[0m"
pkill -f sing-box    2>/dev/null
pkill -f cloudflared 2>/dev/null
pkill -f xray        2>/dev/null
pkill -f hysteria    2>/dev/null

echo -e "\033[0;33m[2/6] 停止并卸载全部 Systemd 守护服务...\033[0m"
for SVC in sing-box cloudflared cloudflared-vless cloudflared-zt; do
    systemctl stop    "$SVC" 2>/dev/null
    systemctl disable "$SVC" 2>/dev/null
done

echo -e "\033[0;33m[3/6] 删除全部服务注册文件...\033[0m"
rm -f /etc/systemd/system/sing-box.service
rm -f /lib/systemd/system/sing-box.service
rm -f /etc/systemd/system/cloudflared.service
rm -f /etc/systemd/system/cloudflared-vless.service
rm -f /etc/systemd/system/cloudflared-zt.service
systemctl daemon-reload

echo -e "\033[0;33m[4/6] 粉碎核心程序、配置文件、证书及日志...\033[0m"
rm -rf /etc/sing-box /etc/cloudflared
rm -f  /usr/local/bin/sing-box
rm -f  /usr/local/bin/sing-box.bak
rm -f  /usr/local/bin/cloudflared
rm -f  /tmp/argo.log

echo -e "\033[0;33m[5/6] 清理全局管理命令和历史安装脚本...\033[0m"
rm -f /usr/local/bin/show-nodes
rm -f /usr/local/bin/port
rm -f install_*.sh clean_*.sh update_singbox.sh

echo -e "\033[0;33m[6/6] 重置防火墙规则...\033[0m"
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    # ufw 已激活：不做 reset（避免误删其他规则），只提示
    echo -e "\033[0;33m  ⚠️  检测到 ufw 处于激活状态，防火墙规则已保留，请自行按需清理。\033[0m"
else
    iptables -F
    iptables -X
    iptables -P INPUT   ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT  ACCEPT
fi

clear
echo -e "\033[0;31m=================================================="
echo -e "   🧹 报告长官：七协议核心 + 配置文件 + 全部隧道   "
echo -e "        服务 + 全局命令 已全部物理粉碎！           "
echo -e "        洗地完毕，VPS 已恢复出厂干净状态。         "
echo -e "==================================================\033[0m"
