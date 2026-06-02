cat << 'EOF' > install_max_matrix.sh
#!/bin/bash
clear
echo -e "\033[0;32m====== 正在部署：完美双栈 + 五协议矩阵 + 随时查看管理面板终极版 ======\033[0m"

# 1. 引导用户输入 Token（支持直接回车跳过）
echo -e "\033[0;33m⚠️  [可选] 请输入 CF Zero Trust 网页上的长 Token（如不使用固定隧道，请直接敲回车跳过）：\033[0m"
read -p "👉 Token (可留空): " USER_TOKEN

# 2. 引导用户输入固定域名（支持直接回车跳过）
echo -e ""
echo -e "\033[0;33m⚠️  [可选] 请输入绑定的固定二级域名（如不使用固定隧道，请直接敲回车跳过）：\033[0m"
read -p "👉 域名 (可留空): " USER_DOMAIN

# 状态标记：判断用户是否启用了固定隧道
if [ -n "$USER_TOKEN" ] && [ -n "$USER_DOMAIN" ]; then
    ENABLE_ZT=true
    USER_DOMAIN=$(echo "$USER_DOMAIN" | tr -d ' ')
    echo -e "\033[0;32m✅ 检测到有效参数，本次安装将开启【临时+固定】双重隧道模式！\033[0m"
else
    ENABLE_ZT=false
    echo -e "\033[0;36m💡 检测到参数留空，已自动切换为【仅拉起 Argo 临时测试隧道】模式！\033[0m"
fi
sleep 1

# 3. 自动补齐基础依赖与纯净 DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
apt update && apt install uuid-runtime openssl wget curl jq ca-certificates -y 2>/dev/null

# 4. 自动下载官方 1.9.3 二进制核心
echo -e "\033[0;33m[1/4] 正在拉取官方预编译核心...\033[0m"
rm -f /usr/local/bin/sing-box
wget -q https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-linux-amd64.tar.gz -O sing-box.tar.gz
if [ $? -ne 0 ]; then
    wget -q https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v1.9.3/sing-box-1.9.3-linux-amd64.tar.gz -O sing-box.tar.gz
fi
tar -zxf sing-box.tar.gz
mv sing-box-1.9.3-linux-amd64/sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box
rm -rf sing-box.tar.gz sing-box-1.9.3-linux-amd64

# 5. 动态参数计算与证书生成
mkdir -p /etc/sing-box
UUID=$(uuidgen)
SUID=$(openssl rand -hex 8)
RANDOM_PATH="/$(openssl rand -hex 4)"
IP4=$(curl -s -4 ip.sb || curl -s -4 ifconfig.me)
IP6=$(curl -s -6 ip.sb || curl -s -6 ifconfig.me 2>/dev/null)

REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair 2>/dev/null)
PRIV_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}')
PUB_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}')
if [ -z "$PRIV_KEY" ]; then
    PRIV_KEY="uGP7X_wWvZV-qX-74V2_Hw0Z8H6FfR8yE5C-d8I3b0E="
    PUB_KEY="x_Xn8H6_WvZV-qX-74V2_Hw0Z8H6FfR8yE5C-d8I3b0E="
fi

openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/server.key -out /etc/sing-box/server.crt -subj "/CN=www.microsoft.com" -days 36500 2>/dev/null

# 将生成的关键元数据固化到本地，供后期 show-nodes 随时调用
cat << EOF > /etc/sing-box/meta_env.sh
PUB_KEY="${PUB_KEY}"
SUID="${SUID}"
RANDOM_PATH="${RANDOM_PATH}"
ENABLE_ZT="${ENABLE_ZT}"
USER_DOMAIN="${USER_DOMAIN}"
EOF

# 6. 灌入五协议配置
echo -e "\033[0;33m[2/4] 正在写入内核五协议矩阵配置...\033[0m"
cat << JSONEOF > /etc/sing-box/config.json
{
  "log": { "level": "warn" },
  "inbounds": [
    {
      "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": 8443,
      "users": [ { "uuid": "${UUID}", "flow": "xtls-rprx-vision" } ],
      "tls": {
        "enabled": true, "server_name": "www.microsoft.com",
        "reality": { "enabled": true, "handshake": { "server": "www.microsoft.com", "server_port": 443 }, "private_key": "${PRIV_KEY}", "short_id": [ "${SUID}" ] }
      }
    },
    {
      "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": 9443,
      "users": [ { "password": "${UUID}" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "tuic", "tag": "tuic5-in", "listen": "::", "listen_port": 10443,
      "users": [ { "uuid": "${UUID}", "password": "${UUID}" } ],
      "tls": { "enabled": true, "server_name": "www.microsoft.com", "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "trojan", "tag": "trojan-in", "listen": "::", "listen_port": 11443,
      "users": [ { "password": "${UUID}" } ],
      "tls": { "enabled": true, "server_name": "www.microsoft.com", "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "vmess", "tag": "vmess-ws-in", "listen": "::", "listen_port": 8080,
      "users": [ { "uuid": "${UUID}" } ],
      "transport": { "type": "ws", "path": "${RANDOM_PATH}" }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
JSONEOF

# 7. 拉起 sing-box 服务
echo -e "\033[0;33m[3/4] 正在拉起系统五协议核心进程...\033[0m"
cat << SVCEOF > /etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
After=network.target nss-lookup.target
[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10s
[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload && systemctl restart sing-box && systemctl enable sing-box

# 8. 弹性部署网络隧道
echo -e "\033[0;33m[4/4] 正在配置 Cloudflare 核心隧道连接器...\033[0m"
rm -f /usr/local/bin/cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

cat << CLOUDFLAREDEOF > /etc/systemd/system/cloudflared.service
[Unit]
Description=cloudflare try tunnel
After=network.target
[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:8080
Restart=on-failure
RestartSec=10s
[Install]
WantedBy=multi-user.target
CLOUDFLAREDEOF

systemctl daemon-reload && systemctl restart cloudflared && systemctl enable cloudflared

if [ "$ENABLE_ZT" = true ]; then
cat << CLOUDFLAREDZTEOF > /etc/systemd/system/cloudflared-zt.service
[Unit]
Description=cloudflare zero trust tunnel
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${USER_TOKEN}
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
CLOUDFLAREDZTEOF

    systemctl daemon-reload && systemctl restart cloudflared-zt && systemctl enable cloudflared-zt
else
    systemctl stop cloudflared-zt 2>/dev/null
    systemctl disable cloudflared-zt 2>/dev/null
    rm -f /etc/systemd/system/cloudflared-zt.service
    systemctl daemon-reload
fi

echo -e "\033[0;33m⏳ 正在等待 Cloudflare 分配边缘测试隧道，大约需要 5-8 秒...\033[0m"
sleep 7

# =========================================================================
# 🌟 核心大招：动态生成独立查看面板脚本，并注册为系统全局命令 show-nodes
# =========================================================================
cat << 'PANELDATA' > /usr/local/bin/show-nodes
#!/bin/bash
if [ ! -f /etc/sing-box/config.json ] || [ ! -f /etc/sing-box/meta_env.sh ]; then
    echo -e "\033[0;31m❌ 错误：未检测到完全体节点的安装环境，请先运行安装脚本！\033[0m"
    exit 1
fi

# 加载元数据环境
source /etc/sing-box/meta_env.sh

# 实时提取核心当前的动态数据
UUID=$(jq -r '.inbounds[0].users[0].uuid' /etc/sing-box/config.json)
IP4=$(curl -s -4 ip.sb || curl -s -4 ifconfig.me)
IP6=$(curl -s -6 ip.sb || curl -s -6 ifconfig.me 2>/dev/null)
ARGO_URL=$(journalctl -u cloudflared -n 50 --no-pager | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" | head -n 1)
PORT_CHECK=$(ss -tulpn | grep sing-box)

clear
echo -e "\033[0;32m=================================================="
echo -e "   👑 终极管理面板：当前 VPS 五协议双栈节点快照   "
echo -e "==================================================\033[0m"
if [ -n "$PORT_CHECK" ]; then
    echo -e "核心监听状态: \033[0;32m正常开启 (8443, 9443, 10443, 11443, 8080 双栈全通)\033[0m"
else
    echo -e "核心监听状态: \033[0;31m端口异常，请检查 sing-box.service 服务\033[0m"
fi

if [ "$ENABLE_ZT" = true ]; then
    echo -e "网络隧道模式: \033[0;32m【双轨齐飞】临时穿透 + 零信任固定后台托管中\033[0m"
else
    echo -e "网络隧道模式: \033[0;36m【单轨轻量】仅开启 Argo 临时测试穿透模式\033[0m"
fi
echo -e "💡 提示：以后随时在终端输入 \033[0;35mshow-nodes\033[0m 即可再次呼出此面板！"
echo -e "--------------------------------------------------"
echo -e "ℹ️  通用密码/UUID: \033[0;32m${UUID}\033[0m"
echo -e "--------------------------------------------------"
echo -e "1️⃣  VLESS Reality 节点:"
echo -e " 👉 IPv4: \033[0;33mvless://${UUID}@${IP4}:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Max-v4-Reality\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mvless://${UUID}@[${IP6}]:8443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Max-v6-Reality\033[0m"
fi
echo -e ""
echo -e "2️⃣  Hysteria 2 节点:"
echo -e " 👉 IPv4: \033[0;33mhy2://${UUID}@${IP4}:9443?insecure=1&sni=www.microsoft.com#Max-v4-Hy2\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mhy2://${UUID}@[${IP6}]:9443?insecure=1&sni=www.microsoft.com#Max-v6-Hy2\033[0m"
fi
echo -e ""
echo -e "3️⃣  TUIC v5 节点 (客户端清空 ALPN):"
echo -e " 👉 IPv4: \033[0;33mtuic://${UUID}:${UUID}@${IP4}:10443?congestion_control=bbr&sni=www.microsoft.com&allow_insecure=1#Max-v4-TUIC5\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtuic://${UUID}:${UUID}@[${IP6}]:10443?congestion_control=bbr&sni=www.microsoft.com&allow_insecure=1#Max-v6-TUIC5\033[0m"
fi
echo -e ""
echo -e "4️⃣  Trojan 节点 (客户端清空 ALPN 且允许不安全证书):"
echo -e " 👉 IPv4: \033[0;33mtrojan://${UUID}@${IP4}:11443?peer=www.microsoft.com&sni=www.microsoft.com&allowInsecure=1#Max-v4-Trojan\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtrojan://${UUID}@[${IP6}]:11443?peer=www.microsoft.com&sni=www.microsoft.com&allowInsecure=1#Max-v6-Trojan\033[0m"
fi
echo -e ""
echo -e "5️⃣  VMess 隧道节点输出区："

if [ "$ENABLE_ZT" = true ]; then
    VMESS_FIXED_JSON="{\"v\":\"2\",\"ps\":\"Argo-零信任固定隧道\",\"add\":\"${USER_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${USER_DOMAIN}\",\"path\":\"${RANDOM_PATH}\",\"tls\":\"tls\"}"
    VMESS_FIXED_LINK="vmess://$(echo -n "${VMESS_FIXED_JSON}" | base64 -w 0)"
    echo -e " 👉 【🌟 零信任永久固定链接】"
    echo -e "     \033[0;35m${VMESS_FIXED_LINK}\033[0m"
fi

if [ -n "$ARGO_URL" ]; then
    TUNNEL_HOST=$(echo "$ARGO_URL" | sed 's/https:\/\///')
    VMESS_TRY_JSON="{\"v\":\"2\",\"ps\":\"Argo-临时测试隧道\",\"add\":\"${TUNNEL_HOST}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${TUNNEL_HOST}\",\"path\":\"${RANDOM_PATH}\",\"tls\":\"tls\"}"
    VMESS_TRY_LINK="vmess://$(echo -n "${VMESS_TRY_JSON}" | base64 -w 0)"
    echo -e " 👉 【⚡ Argo 临时测试链接（重启机器失效备用）】"
    echo -e "     \033[0;36m${VMESS_TRY_LINK}\033[0m"
else
    echo -e " ❌ 提示：Cloudflare 临时穿透失败，可能由于本地机房请求频繁死锁"
fi
echo -e "=================================================="
PANELDATA

# 赋予查看脚本全局执行权限
chmod +x /usr/local/bin/show-nodes

# 安装完成直接首次呼出面板
show-nodes
EOF
chmod +x install_max_matrix.sh
./install_max_matrix.sh
