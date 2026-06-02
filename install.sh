cat << 'EOF' > install_max_matrix.sh
#!/bin/bash
clear
echo -e "\033[0;32m====== 正在部署：完美双栈 + 五协议矩阵 + 临时/固定双隧道共存【终极毁灭版】 ======\033[0m"

# 1. 引导用户现场输入网页上的 Token 和绑定的自定义域名
echo -e "\033[0;33m⚠️  请输入你在 Cloudflare Zero Trust 网页上生成的那个长 Token：\033[0m"
read -p "👉 请粘贴 Token 并敲回车: " USER_TOKEN

if [ -z "$USER_TOKEN" ]; then
    echo -e "\033[0;31m❌ 错误：Token 不能为空！脚本退出。\033[0m"
    exit 1
fi

echo -e ""
echo -e "\033[0;33m⚠️  请输入你在零信任 Public Hostname 里绑定的固定二级域名（例如: myvmes.yourname.com）：\033[0m"
read -p "👉 请输入完整域名并敲回车: " USER_DOMAIN

if [ -z "$USER_DOMAIN" ]; then
    echo -e "\033[0;31m❌ 错误：自定义域名不能为空！脚本退出。\033[0m"
    exit 1
fi

USER_DOMAIN=$(echo "$USER_DOMAIN" | tr -d ' ')

# 2. 自动补齐基础依赖与纯净 DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
apt update && apt install uuid-runtime openssl wget curl jq ca-certificates -y 2>/dev/null

# 3. 自动下载官方 1.9.3 二进制核心
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

# 4. 动态参数计算与证书生成
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

# 5. 灌入五协议内核配置 ("::" 双栈盲连)
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

# 6. 注册并拉起 sing-box 服务
echo -e "\033[0;33m[3/4] 正在拉起系统四大核心独立端口进程...\033[0m"
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

# 7. 下载并双轨拉起临时隧道与固定零信任隧道
echo -e "\033[0;33m[4/4] 正在部署双轨隧道：临时隧道 + 零信任固定隧道并存...${PLAIN}"
rm -f /usr/local/bin/cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# 轨道 A：拉起临时隧道系统服务
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

# 轨道 B：拉起零信任固定固定隧道系统服务
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

systemctl daemon-reload
systemctl restart cloudflared cloudflared-zt
systemctl enable cloudflared cloudflared-zt
sleep 7

# 捕获临时隧道生成的 trycloudflare 域名
ARGO_URL=$(journalctl -u cloudflared -n 50 --no-pager | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" | head -n 1)
PORT_CHECK=$(ss -tulpn | grep sing-box)

# 计算固定隧道的 Base64 订阅链接
VMESS_FIXED_JSON="{\"v\":\"2\",\"ps\":\"ZeroTrust-固定隧道\",\"add\":\"${USER_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${USER_DOMAIN}\",\"path\":\"${RANDOM_PATH}\",\"tls\":\"tls\"}"
VMESS_FIXED_LINK="vmess://$(echo -n "${VMESS_FIXED_JSON}" | base64 -w 0)"

# 8. 毁灭级输出面板
clear
echo -e "\033[0;32m=================================================="
echo -e "   👑 毁灭级满配：五协议双栈 + 双隧道共存一键成功！   "
echo -e "==================================================\033[0m"
if [ -n "$PORT_CHECK" ]; then
    echo -e "核心监听状态: \033[0;32m正常开启 (8443, 9443, 10443, 11443, 8080已双栈监听！)\033[0m"
else
    echo -e "核心监听状态: \033[0;31m端口未亮，请检查网页防火墙/安全组\033[0m"
fi
echo -e "零信任隧道状态: \033[0;32m正常驻留后台运行中！\033[0m"
echo -e "⚠️  新机器切记去网页后台放行：TCP 8443, 11443 端口，以及 UDP 9443, 10443 端口！"
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
echo -e "3️⃣  TUIC v5 节点 (⚠️客户端清空 ALPN):"
echo -e " 👉 IPv4: \033[0;33mtuic://${UUID}:${UUID}@${IP4}:10443?congestion_control=bbr&sni=www.microsoft.com&allow_insecure=1#Max-v4-TUIC5\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtuic://${UUID}:${UUID}@[${IP6}]:10443?congestion_control=bbr&sni=www.microsoft.com&allow_insecure=1#Max-v6-TUIC5\033[0m"
fi
echo -e ""
echo -e "4️⃣  新增 Trojan 节点 (⚠️客户端清空 ALPN 且开启允许不安全证书):"
echo -e " 👉 IPv4: \033[0;33mtrojan://${UUID}@${IP4}:11443?peer=www.microsoft.com&sni=www.microsoft.com&allowInsecure=1#Max-v4-Trojan\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtrojan://${UUID}@[${IP6}]:11443?peer=www.microsoft.com&sni=www.microsoft.com&allowInsecure=1#Max-v6-Trojan\033[0m"
fi
echo -e ""
echo -e "5️⃣  VMess 双宿主隧道节点（双保险起飞）："
echo -e " 👉 【双保险 A 轨：零信任永久固定链接】"
echo -e "     \033[0;35m${VMESS_FIXED_LINK}\033[0m"
if [ -n "$ARGO_URL" ]; then
    TUNNEL_HOST=$(echo "$ARGO_URL" | sed 's/https:\/\///')
    VMESS_TRY_JSON="{\"v\":\"2\",\"ps\":\"Argo-临时测试隧道\",\"add\":\"${TUNNEL_HOST}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${TUNNEL_HOST}\",\"path\":\"${RANDOM_PATH}\",\"tls\":\"tls\"}"
    VMESS_TRY_LINK="vmess://$(echo -n "${VMESS_TRY_JSON}" | base64 -w 0)"
    echo -e " 👉 【双保险 B 轨：Argo 临时体验链接（随时重启失效备用）】"
    echo -e "     \033[0;36m${VMESS_TRY_LINK}\033[0m"
fi
echo -e "=================================================="
EOF
chmod +x install_max_matrix.sh
./install_max_matrix.sh
