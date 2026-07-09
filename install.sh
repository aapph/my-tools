cat << 'EOF' > install_max_matrix.sh
#!/bin/bash
clear
echo -e "\033[0;32m==================================================================\033[0m"
echo -e "\033[0;32m👑 终极大满配：七协议矩阵 + 弹性双隧道 + 端口/域名双控制面板完全体 👑\033[0m"
echo -e "\033[0;32m==================================================================\033[0m"

# 1. 引导用户输入 Token 和域名（支持直接回车跳过）
echo -e "\033[0;33m⚠️  [可选] 请输入 CF Zero Trust 网页上的长 Token（不使用固定隧道请直接回车）：\033[0m"
read -p "👉 Token (可留空): " USER_TOKEN

echo -e ""
echo -e "\033[0;33m⚠️  [可选] 请输入绑定的固定二级域名（不使用固定隧道请直接回车）：\033[0m"
read -p "👉 域名 (可留空): " USER_DOMAIN

if [ -n "$USER_TOKEN" ] && [ -n "$USER_DOMAIN" ]; then
    ENABLE_ZT=true
    USER_DOMAIN=$(echo "$USER_DOMAIN" | tr -d ' ')
    echo -e "\033[0;32m✅ 本次安装将开启【临时+固定】双重隧道模式！\033[0m"
else
    ENABLE_ZT=false
    echo -e "\033[0;36m💡 已自动切换为【仅拉起 Argo 临时测试隧道】模式！\033[0m"
fi

USER_DOMAIN_VLESS=""
if [ "$ENABLE_ZT" = true ]; then
    echo -e ""
    echo -e "\033[0;33m⚠️  [可选] VLESS 也可以复用同一个固定隧道 Token。若要用它额外挂一个 VLESS 专用二级域名，"
    echo -e "     需要之后自行在 CF Zero Trust 后台给该 Tunnel 新增一条 Public Hostname，指向本机 VLESS 隧道端口（下面会提示端口号）。"
    echo -e "     不需要的话直接回车，届时只生成 VLESS 的 Argo 临时测试链接。\033[0m"
    read -p "👉 VLESS 固定隧道二级域名 (可留空): " USER_DOMAIN_VLESS
    USER_DOMAIN_VLESS=$(echo "$USER_DOMAIN_VLESS" | tr -d ' ')
fi
sleep 1

# 2. 交互式自定义节点端口（回车即用默认值）
echo -e "\n\033[0;32m--------------------------------------------------\033[0m"
echo -e "\033[0;32m🛠️  自定义端口配置区（直接回车即使用默认经典端口）：\033[0m"
echo -e "\033[0;32m--------------------------------------------------\033[0m"

RANDOM_VLESS_DEFAULT=$(( (RANDOM % 30000) + 20000 ))
read -p "👉 1. VLESS Reality 端口 (回车随机生成，建议直连协议不要用8443/2053等CDN常用端口): " PORT_VLESS
PORT_VLESS=${PORT_VLESS:-$RANDOM_VLESS_DEFAULT}

read -p "👉 2. Hysteria 2 端口 (默认: 9886): " PORT_HY2
PORT_HY2=${PORT_HY2:-9886}

read -p "👉 3. TUIC v5 端口 (默认: 19886): " PORT_TUIC
PORT_TUIC=${PORT_TUIC:-19886}

read -p "👉 4. Trojan 端口 (默认: 29886): " PORT_TROJAN
PORT_TROJAN=${PORT_TROJAN:-29886}

read -p "👉 5. VMess 本地转发端口 (默认: 8080): " PORT_VMESS
PORT_VMESS=${PORT_VMESS:-8080}

read -p "👉 6. VLESS Argo 隧道本地端口 (仅监听127.0.0.1，不直接暴露公网，默认: 8880): " PORT_VLESS_ARGO
PORT_VLESS_ARGO=${PORT_VLESS_ARGO:-8880}

echo -e "\n\033[0;32m✅ 端口矩阵已锁定：VLESS($PORT_VLESS) | Hy2($PORT_HY2) | TUIC($PORT_TUIC) | Trojan($PORT_TROJAN) | VMess本地($PORT_VMESS) | VLESS-Argo本地($PORT_VLESS_ARGO)\033[0m"
sleep 1

# 2.1 VMess / VLESS-WS-TLS 可套CDN节点配置（使用 Cloudflare 支持的 HTTPS 端口，便于走优选IP/优选域名）
echo -e "\n\033[0;32m--------------------------------------------------\033[0m"
echo -e "\033[0;32m🛡️  VMess / VLESS-WS-TLS 可套CDN节点配置（适配 Cloudflare 优选IP/优选域名加速）：\033[0m"
echo -e "\033[0;32m--------------------------------------------------\033[0m"
echo -e "Cloudflare 放行以下几个 HTTPS 端口用于回源，请选择一个用作 VMess+TLS+WS 的CDN落地端口："
echo -e "  [1] 2053   [2] 2083   [3] 2087   [4] 2096   [5] 8443 (默认: 1 -> 2053)"
read -p "👉 请输入编号 (1-5，默认1): " CDN_PORT_CHOICE
case "$CDN_PORT_CHOICE" in
    2) PORT_VMESS_CDN=2083 ;;
    3) PORT_VMESS_CDN=2087 ;;
    4) PORT_VMESS_CDN=2096 ;;
    5) PORT_VMESS_CDN=8443 ;;
    *) PORT_VMESS_CDN=2053 ;;
esac

echo -e "再选一个用作 VLESS+TLS+WS 的CDN落地端口（建议与上面不同，一台机器多套CDN节点互为备用）："
echo -e "  [1] 443    [2] 2053   [3] 2083   [4] 2087   [5] 2096   [6] 8443 (默认: 2 -> 2053)"
read -p "👉 请输入编号 (1-6，默认2): " VLESS_CDN_PORT_CHOICE
case "$VLESS_CDN_PORT_CHOICE" in
    1) PORT_VLESS_WS_CDN=443  ;;
    2) PORT_VLESS_WS_CDN=2053 ;;
    3) PORT_VLESS_WS_CDN=2083 ;;
    4) PORT_VLESS_WS_CDN=2087 ;;
    5) PORT_VLESS_WS_CDN=2096 ;;
    6) PORT_VLESS_WS_CDN=8443 ;;
    *) PORT_VLESS_WS_CDN=2053 ;;
esac

echo -e "\033[0;33m⚠️  [可选] 请输入你已添加到 Cloudflare 并开启橙云代理(Proxied)的域名，VMess 和 VLESS-WS-TLS 的CDN节点共用同一个域名、"
echo -e "     不同端口即可（不使用可直接回车，后续可用 port 命令补充）：\033[0m"
read -p "👉 CDN域名 (可留空): " CDN_DOMAIN
CDN_DOMAIN=$(echo "$CDN_DOMAIN" | tr -d ' ')

echo -e "\n\033[0;32m✅ VMess CDN 端口：${PORT_VMESS_CDN} | VLESS-WS-TLS CDN 端口：${PORT_VLESS_WS_CDN}（域名：${CDN_DOMAIN:-未设置}）\033[0m"
sleep 1

# 2.1.1 自定义 SNI 伪装域名（用于 Reality/TLS 握手伪装，默认 www.bing.com，可自定义）
echo -e "\n\033[0;32m--------------------------------------------------\033[0m"
echo -e "\033[0;32m🎭  TLS/Reality 伪装 SNI 域名配置：\033[0m"
echo -e "\033[0;32m--------------------------------------------------\033[0m"
read -p "👉 请输入用于握手伪装的 SNI 域名 (直接回车默认使用 www.bing.com): " SNI_DOMAIN
SNI_DOMAIN=${SNI_DOMAIN:-www.bing.com}
echo -e "\033[0;32m✅ 伪装 SNI 已设置为：${SNI_DOMAIN}\033[0m"
sleep 1

# 2.2 端口冲突自动检测：所有端口里如有重复，自动把后选的那个顺延+1，直到不冲突为止
echo -e "\033[0;33m🔍 正在检测端口矩阵是否存在冲突...\033[0m"
USED_PORTS=()
fix_conflict() {
    local VAR_NAME=$1
    local PORT_VAL=${!VAR_NAME}
    while [[ " ${USED_PORTS[*]} " == *" ${PORT_VAL} "* ]]; do
        PORT_VAL=$((PORT_VAL + 1))
    done
    USED_PORTS+=("${PORT_VAL}")
    eval "${VAR_NAME}=${PORT_VAL}"
}
fix_conflict PORT_VLESS
fix_conflict PORT_HY2
fix_conflict PORT_TUIC
fix_conflict PORT_TROJAN
fix_conflict PORT_VMESS
fix_conflict PORT_VMESS_CDN
fix_conflict PORT_VLESS_WS_CDN
# 注意：PORT_VLESS_ARGO 仅监听 127.0.0.1，与以上公网端口不在同一命名空间竞争，不参与冲突检测
echo -e "\033[0;32m✅ 冲突检测完成，最终端口矩阵：VLESS($PORT_VLESS) | Hy2($PORT_HY2) | TUIC($PORT_TUIC) | Trojan($PORT_TROJAN) | VMess本地($PORT_VMESS) | VMess CDN($PORT_VMESS_CDN) | VLESS-WS-TLS CDN($PORT_VLESS_WS_CDN) | VLESS-Argo本地($PORT_VLESS_ARGO)\033[0m"
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
RANDOM_PATH2="/$(openssl rand -hex 4)"
RANDOM_PATH3="/$(openssl rand -hex 4)"
IP4=$(curl -s -4 ip.sb || curl -s -4 ifconfig.me)
IP6=$(curl -s -6 ip.sb || curl -s -6 ifconfig.me 2>/dev/null)

REALITY_KEYS=$(/usr/local/bin/sing-box generate reality-keypair 2>/dev/null)
PRIV_KEY=$(echo "$REALITY_KEYS" | grep "PrivateKey" | awk '{print $2}')
PUB_KEY=$(echo "$REALITY_KEYS" | grep "PublicKey" | awk '{print $2}')
if [ -z "$PRIV_KEY" ]; then
    PRIV_KEY="uGP7X_wWvZV-qX-74V2_Hw0Z8H6FfR8yE5C-d8I3b0E="
    PUB_KEY="x_Xn8H6_WvZV-qX-74V2_Hw0Z8H6FfR8yE5C-d8I3b0E="
fi

openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/server.key -out /etc/sing-box/server.crt -subj "/CN=${SNI_DOMAIN}" -days 36500 2>/dev/null

# 将自定义端口、Token和元数据固化到本地，供后期面板随时提取修改
cat << METEOF > /etc/sing-box/meta_env.sh
PUB_KEY="${PUB_KEY}"
SUID="${SUID}"
RANDOM_PATH="${RANDOM_PATH}"
RANDOM_PATH2="${RANDOM_PATH2}"
RANDOM_PATH3="${RANDOM_PATH3}"
SNI_DOMAIN="${SNI_DOMAIN}"
ENABLE_ZT="${ENABLE_ZT}"
USER_DOMAIN="${USER_DOMAIN}"
USER_DOMAIN_VLESS="${USER_DOMAIN_VLESS}"
USER_TOKEN="${USER_TOKEN}"
PORT_VLESS="${PORT_VLESS}"
PORT_HY2="${PORT_HY2}"
PORT_TUIC="${PORT_TUIC}"
PORT_TROJAN="${PORT_TROJAN}"
PORT_VMESS="${PORT_VMESS}"
PORT_VMESS_CDN="${PORT_VMESS_CDN}"
PORT_VLESS_WS_CDN="${PORT_VLESS_WS_CDN}"
PORT_VLESS_ARGO="${PORT_VLESS_ARGO}"
CDN_DOMAIN="${CDN_DOMAIN}"
METEOF

# 6. 灌入自定义端口的七协议配置
echo -e "\033[0;33m[2/4] 正在写入内核协议矩阵配置...\033[0m"
cat << JSONEOF > /etc/sing-box/config.json
{
  "log": { "level": "warn" },
  "inbounds": [
    {
      "type": "vless", "tag": "vless-reality-in", "listen": "::", "listen_port": ${PORT_VLESS},
      "users": [ { "uuid": "${UUID}", "flow": "xtls-rprx-vision" } ],
      "tls": {
        "enabled": true, "server_name": "${SNI_DOMAIN}",
        "reality": { "enabled": true, "handshake": { "server": "${SNI_DOMAIN}", "server_port": 443 }, "private_key": "${PRIV_KEY}", "short_id": [ "${SUID}" ] }
      }
    },
    {
      "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": ${PORT_HY2},
      "users": [ { "password": "${UUID}" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "tuic", "tag": "tuic5-in", "listen": "::", "listen_port": ${PORT_TUIC},
      "users": [ { "uuid": "${UUID}", "password": "${UUID}" } ],
      "tls": { "enabled": true, "server_name": "${SNI_DOMAIN}", "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "trojan", "tag": "trojan-in", "listen": "::", "listen_port": ${PORT_TROJAN},
      "users": [ { "password": "${UUID}" } ],
      "tls": { "enabled": true, "server_name": "${SNI_DOMAIN}", "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" }
    },
    {
      "type": "vmess", "tag": "vmess-ws-in", "listen": "::", "listen_port": ${PORT_VMESS},
      "users": [ { "uuid": "${UUID}" } ],
      "transport": { "type": "ws", "path": "${RANDOM_PATH}" }
    },
    {
      "type": "vmess", "tag": "vmess-cdn-in", "listen": "::", "listen_port": ${PORT_VMESS_CDN},
      "users": [ { "uuid": "${UUID}" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" },
      "transport": { "type": "ws", "path": "${RANDOM_PATH}" }
    },
    {
      "type": "vless", "tag": "vless-ws-cdn-in", "listen": "::", "listen_port": ${PORT_VLESS_WS_CDN},
      "users": [ { "uuid": "${UUID}" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/sing-box/server.crt", "key_path": "/etc/sing-box/server.key" },
      "transport": { "type": "ws", "path": "${RANDOM_PATH2}" }
    },
    {
      "type": "vless", "tag": "vless-argo-in", "listen": "127.0.0.1", "listen_port": ${PORT_VLESS_ARGO},
      "users": [ { "uuid": "${UUID}" } ],
      "transport": { "type": "ws", "path": "${RANDOM_PATH3}" }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
JSONEOF

# 7. 注册并拉起 sing-box 服务
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

# 7.1 自动放行防火墙端口（ufw 优先，没有则走 iptables，避免端口被墙导致节点不通）
# 注意：PORT_VLESS_ARGO 仅监听 127.0.0.1，只供本机 cloudflared 回源使用，不对公网开放，因此不加入放行列表
echo -e "\033[0;33m🔓 正在自动放行所有协议端口的防火墙规则...\033[0m"
ALL_PORTS=("${PORT_VLESS}" "${PORT_HY2}" "${PORT_TUIC}" "${PORT_TROJAN}" "${PORT_VMESS}" "${PORT_VMESS_CDN}" "${PORT_VLESS_WS_CDN}")
if command -v ufw >/dev/null 2>&1; then
    for P in "${ALL_PORTS[@]}"; do
        ufw allow ${P}/tcp >/dev/null 2>&1
        ufw allow ${P}/udp >/dev/null 2>&1
    done
    ufw reload >/dev/null 2>&1
else
    for P in "${ALL_PORTS[@]}"; do
        iptables -I INPUT -p tcp --dport ${P} -j ACCEPT 2>/dev/null
        iptables -I INPUT -p udp --dport ${P} -j ACCEPT 2>/dev/null
    done
fi
echo -e "\033[0;32m✅ 端口矩阵已在防火墙层放行：${ALL_PORTS[*]}\033[0m"

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
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:${PORT_VMESS}
Restart=on-failure
RestartSec=10s
[Install]
WantedBy=multi-user.target
CLOUDFLAREDEOF

systemctl daemon-reload && systemctl restart cloudflared && systemctl enable cloudflared

# 8.1 VLESS 专用 Argo 临时隧道（独立进程，独立 trycloudflare.com 域名，互不影响 VMess 隧道）
cat << CLOUDFLAREDVLESSEOF > /etc/systemd/system/cloudflared-vless.service
[Unit]
Description=cloudflare try tunnel for vless
After=network.target
[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:${PORT_VLESS_ARGO}
Restart=on-failure
RestartSec=10s
[Install]
WantedBy=multi-user.target
CLOUDFLAREDVLESSEOF

systemctl daemon-reload && systemctl restart cloudflared-vless && systemctl enable cloudflared-vless

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
# 🌟 大招一：【随时查看面板】常驻脚本注册全局命令 show-nodes
# =========================================================================
cat << 'PANELDATA' > /usr/local/bin/show-nodes
#!/bin/bash
if [ ! -f /etc/sing-box/config.json ] || [ ! -f /etc/sing-box/meta_env.sh ]; then
    echo -e "\033[0;31m❌ 错误：未检测到完全体节点的安装环境，请先运行安装脚本！\033[0m"
    exit 1
fi
source /etc/sing-box/meta_env.sh
UUID=$(jq -r '.inbounds[0].users[0].uuid' /etc/sing-box/config.json)
IP4=$(curl -s -4 ip.sb || curl -s -4 ifconfig.me)
IP6=$(curl -s -6 ip.sb || curl -s -6 ifconfig.me 2>/dev/null)
ARGO_URL=$(journalctl -u cloudflared -n 50 --no-pager | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" | head -n 1)
PORT_CHECK=$(ss -tulpn | grep sing-box)

clear
echo -e "\033[0;32m=================================================="
echo -e "   👑 终极管理面板：当前 VPS 七协议全栈节点快照   "
echo -e "==================================================\033[0m"
if [ -n "$PORT_CHECK" ]; then
    echo -e "核心监听状态: \033[0;32m正常开启 (${PORT_VLESS}, ${PORT_HY2}, ${PORT_TUIC}, ${PORT_TROJAN}, ${PORT_VMESS} 双栈全通)\033[0m"
else
    echo -e "核心监听状态: \033[0;31m端口异常，请检查 sing-box.service 服务\033[0m"
fi

if [ "$ENABLE_ZT" = true ]; then
    echo -e "网络隧道模式: \033[0;32m【双轨齐飞】临时穿透 + 零信任固定后台托管中\033[0m"
    echo -e "当前固定域名: \033[0;35m${USER_DOMAIN}\033[0m"
else
    echo -e "网络隧道模式: \033[0;36m【单轨轻量】仅开启 Argo 临时测试穿透模式\033[0m"
fi
echo -e "当前伪装 SNI : \033[0;35m${SNI_DOMAIN}\033[0m"
echo -e "💡 提示：以后随时在终端输入 \033[0;35mshow-nodes\033[0m 即可再次呼出此面板！"
echo -e "--------------------------------------------------"
echo -e "ℹ️  通用密码/UUID: \033[0;32m${UUID}\033[0m"
echo -e "--------------------------------------------------"
echo -e "1️⃣  VLESS Reality 节点:"
echo -e " 👉 IPv4: \033[0;33mvless://${UUID}@${IP4}:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_DOMAIN}&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Max-v4-Reality\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mvless://${UUID}@[${IP6}]:${PORT_VLESS}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI_DOMAIN}&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Max-v6-Reality\033[0m"
fi
echo -e ""
echo -e "2️⃣  Hysteria 2 节点:"
echo -e " 👉 IPv4: \033[0;33mhy2://${UUID}@${IP4}:${PORT_HY2}?insecure=1&sni=${SNI_DOMAIN}#Max-v4-Hy2\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mhy2://${UUID}@[${IP6}]:${PORT_HY2}?insecure=1&sni=${SNI_DOMAIN}#Max-v6-Hy2\033[0m"
fi
echo -e ""
echo -e "3️⃣  TUIC v5 节点 (客户端清空 ALPN):"
echo -e " 👉 IPv4: \033[0;33mtuic://${UUID}:${UUID}@${IP4}:${PORT_TUIC}?congestion_control=bbr&sni=${SNI_DOMAIN}&allow_insecure=1#Max-v4-TUIC5\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtuic://${UUID}:${UUID}@[${IP6}]:${PORT_TUIC}?congestion_control=bbr&sni=${SNI_DOMAIN}&allow_insecure=1#Max-v6-TUIC5\033[0m"
fi
echo -e ""
echo -e "4️⃣  Trojan 节点 (客户端清空 ALPN 且允许不安全证书):"
echo -e " 👉 IPv4: \033[0;33mtrojan://${UUID}@${IP4}:${PORT_TROJAN}?peer=${SNI_DOMAIN}&sni=${SNI_DOMAIN}&allowInsecure=1#Max-v4-Trojan\033[0m"
if [ -n "$IP6" ]; then
echo -e " 👉 IPv6: \033[0;33mtrojan://${UUID}@[${IP6}]:${PORT_TROJAN}?peer=${SNI_DOMAIN}&sni=${SNI_DOMAIN}&allowInsecure=1#Max-v6-Trojan\033[0m"
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
echo -e ""
echo -e "6️⃣  VMess 套CDN节点（可用 Cloudflare 优选IP / 优选域名加速）："
if [ -n "$CDN_DOMAIN" ]; then
    VMESS_CDN_JSON="{\"v\":\"2\",\"ps\":\"VMess-套CDN-优选加速\",\"add\":\"${CDN_DOMAIN}\",\"port\":\"${PORT_VMESS_CDN}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${CDN_DOMAIN}\",\"path\":\"${RANDOM_PATH}\",\"tls\":\"tls\",\"sni\":\"${CDN_DOMAIN}\"}"
    VMESS_CDN_LINK="vmess://$(echo -n "${VMESS_CDN_JSON}" | base64 -w 0)"
    echo -e " 👉 域名：\033[0;35m${CDN_DOMAIN}\033[0m  端口：\033[0;35m${PORT_VMESS_CDN}\033[0m（需在 Cloudflare 该域名 DNS 记录上开启橙云代理）"
    echo -e " 👉 节点链接：\033[0;33m${VMESS_CDN_LINK}\033[0m"
    echo -e " 💡 套优选IP用法：客户端把上方链接中的「地址(add)」字段替换为你的优选IP，"
    echo -e "     保持「Host」与「SNI」字段不变(仍为 ${CDN_DOMAIN})，即可实现优选IP/优选域名加速。"
else
    echo -e " ⚠️  尚未绑定CDN域名，请运行 \033[0;35mport\033[0m 命令，选择对应菜单项绑定一个已在 Cloudflare 开启橙云代理的域名后即可生成节点。"
    echo -e " ℹ️  当前预留CDN落地端口：\033[0;33m${PORT_VMESS_CDN}\033[0m（Cloudflare支持: 2053/2083/2087/2096/8443）"
fi
echo -e ""
echo -e "7️⃣  VLESS-WS-TLS 套CDN节点（可用 Cloudflare 优选IP / 优选域名加速，支持443/2053/2083/2087/2096/8443）："
if [ -n "$CDN_DOMAIN" ]; then
    VLESS_CDN_LINK="vless://${UUID}@${CDN_DOMAIN}:${PORT_VLESS_WS_CDN}?encryption=none&security=tls&sni=${CDN_DOMAIN}&type=ws&host=${CDN_DOMAIN}&path=$(echo -n "${RANDOM_PATH2}" | sed 's/\//%2F/g')#Max-VLESS-WS-CDN"
    echo -e " 👉 域名：\033[0;35m${CDN_DOMAIN}\033[0m  端口：\033[0;35m${PORT_VLESS_WS_CDN}\033[0m（需在 Cloudflare 该域名 DNS 记录上开启橙云代理）"
    echo -e " 👉 节点链接：\033[0;33m${VLESS_CDN_LINK}\033[0m"
    echo -e " 💡 套优选IP用法：客户端把链接中的地址字段替换为你的优选IP，Host/SNI 保持 ${CDN_DOMAIN} 不变即可。"
else
    echo -e " ⚠️  尚未绑定CDN域名，请运行 \033[0;35mport\033[0m 命令绑定域名后即可生成节点（与 VMess CDN 共用同一域名，端口各自独立）。"
    echo -e " ℹ️  当前预留CDN落地端口：\033[0;33m${PORT_VLESS_WS_CDN}\033[0m"
fi
echo -e ""
echo -e "8️⃣  VLESS Argo 隧道节点输出区："
if [ -n "$USER_DOMAIN_VLESS" ]; then
    VLESS_ZT_LINK="vless://${UUID}@${USER_DOMAIN_VLESS}:443?encryption=none&security=tls&sni=${USER_DOMAIN_VLESS}&type=ws&host=${USER_DOMAIN_VLESS}&path=$(echo -n "${RANDOM_PATH3}" | sed 's/\//%2F/g')#Max-VLESS-Argo"
    echo -e " 👉 【🌟 零信任永久固定链接】（需已在 CF Zero Trust 后台为该 Tunnel 添加一条 Public Hostname 指向 http://localhost:${PORT_VLESS_ARGO}）"
    echo -e "     \033[0;35m${VLESS_ZT_LINK}\033[0m"
fi
ARGO_URL_VLESS=$(journalctl -u cloudflared-vless -n 50 --no-pager 2>/dev/null | grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" | head -n 1)
if [ -n "$ARGO_URL_VLESS" ]; then
    TUNNEL_HOST_VLESS=$(echo "$ARGO_URL_VLESS" | sed 's/https:\/\///')
    VLESS_TRY_LINK="vless://${UUID}@${TUNNEL_HOST_VLESS}:443?encryption=none&security=tls&sni=${TUNNEL_HOST_VLESS}&type=ws&host=${TUNNEL_HOST_VLESS}&path=$(echo -n "${RANDOM_PATH3}" | sed 's/\//%2F/g')#Max-VLESS-临时Argo"
    echo -e " 👉 【⚡ Argo 临时测试链接（重启机器失效备用）】"
    echo -e "     \033[0;36m${VLESS_TRY_LINK}\033[0m"
else
    echo -e " ❌ 提示：Cloudflare 临时穿透失败，可能由于本地机房请求频繁死锁"
fi
echo -e "=================================================="
PANELDATA
chmod +x /usr/local/bin/show-nodes

# =========================================================================
# 🌟 大招二：【控制台 2.0 满配版】常驻脚本注册全局命令 port (支持改端口+改域名+改Token)
# =========================================================================
cat << 'PORTPANEL' > /usr/local/bin/port
#!/bin/bash
if [ ! -f /etc/sing-box/config.json ] || [ ! -f /etc/sing-box/meta_env.sh ]; then
    echo -e "\033[0;31m❌ 错误：未检测到完全体节点环境，请先安装！\033[0m"
    exit 1
fi
source /etc/sing-box/meta_env.sh
open_port() {
    local P=$1
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${P}/tcp >/dev/null 2>&1
        ufw allow ${P}/udp >/dev/null 2>&1
    else
        iptables -I INPUT -p tcp --dport ${P} -j ACCEPT 2>/dev/null
        iptables -I INPUT -p udp --dport ${P} -j ACCEPT 2>/dev/null
    fi
}
clear
echo -e "\033[0;32m=================================================="
echo -e "   ⚙️  七协议矩阵 · 端口/域名/SNI 动态控制台       "
echo -e "=================================================="
echo -e "当前各协议及隧道配置快照："
echo -e "  [1] VLESS Reality 端口 : \033[0;33m${PORT_VLESS}\033[0m"
echo -e "  [2] Hysteria 2    端口 : \033[0;33m${PORT_HY2}\033[0m"
echo -e "  [3] TUIC v5       端口 : \033[0;33m${PORT_TUIC}\033[0m"
echo -e "  [4] Trojan        端口 : \033[0;33m${PORT_TROJAN}\033[0m"
echo -e "  [5] VMess 本地转发 端口 : \033[0;33m${PORT_VMESS}\033[0m"
echo -e "  [9] VMess 套CDN    端口 : \033[0;33m${PORT_VMESS_CDN}\033[0m"
echo -e "  [10] VMess 套CDN   域名 : \033[0;35m${CDN_DOMAIN:-未绑定}\033[0m"
echo -e "  [11] VLESS-WS-TLS 套CDN 端口 : \033[0;33m${PORT_VLESS_WS_CDN}\033[0m（域名与[10]共用）"
echo -e "  [12] VLESS Argo 本地端口     : \033[0;33m${PORT_VLESS_ARGO}\033[0m（仅127.0.0.1）"
echo -e "  [13] VLESS Argo 固定域名     : \033[0;35m${USER_DOMAIN_VLESS:-未绑定}\033[0m"
echo -e "  [14] 伪装 SNI 域名           : \033[0;35m${SNI_DOMAIN:-www.bing.com}\033[0m"
echo -e "--------------------------------------------------"
if [ "$ENABLE_ZT" = true ]; then
echo -e "  [6] 🌐 修改固定隧道域名: \033[0;35m${USER_DOMAIN}\033[0m"
echo -e "  [7] 🔑 修改固定隧道 Token: \033[0;35m(已隐藏)\033[0m"
else
echo -e "  [6] 🌐 激活并绑定固定隧道域名 (当前处于关闭状态)"
echo -e "  [7] 🔑 现场贴入固定隧道 Token"
fi
echo -e "  [8] ❌ 放弃修改，直接退出"
echo -e "==================================================\033[0m"
read -p "👉 请输入你要调校的菜单编号 (1-8，或 9-14 调整CDN端口/域名/SNI/Argo): " CHOICE

case $CHOICE in
    1)
        read -p "👉 请输入全新的 VLESS 端口 (当前: ${PORT_VLESS}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_VLESS}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_VLESS=\"${PORT_VLESS}\"/PORT_VLESS=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ VLESS 端口已成功修改为 ${NEW_PORT}！\033[0m"
            systemctl restart sing-box
            open_port "${NEW_PORT}"
        fi
        ;;
    2)
        read -p "👉 请输入全新的 Hysteria 2 端口 (当前: ${PORT_HY2}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_HY2}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_HY2=\"${PORT_HY2}\"/PORT_HY2=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ Hysteria 2 端口已成功修改为 ${NEW_PORT}！\033[0m"
            systemctl restart sing-box
            open_port "${NEW_PORT}"
        fi
        ;;
    3)
        read -p "👉 请输入全新的 TUIC v5 端口 (当前: ${PORT_TUIC}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_TUIC}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_TUIC=\"${PORT_TUIC}\"/PORT_TUIC=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ TUIC v5 端口已成功修改为 ${NEW_PORT}！\033[0m"
            systemctl restart sing-box
            open_port "${NEW_PORT}"
        fi
        ;;
    4)
        read -p "👉 请输入全新的 Trojan 端口 (当前: ${PORT_TROJAN}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_TROJAN}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_TROJAN=\"${PORT_TROJAN}\"/PORT_TROJAN=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ Trojan 端口已成功修改为 ${NEW_PORT}！\033[0m"
            systemctl restart sing-box
            open_port "${NEW_PORT}"
        fi
        ;;
    5)
        read -p "👉 请输入全新的 VMess 本地转发端口 (当前: ${PORT_VMESS}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_VMESS}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_VMESS=\"${PORT_VMESS}\"/PORT_VMESS=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            sed -i "s/http:\/\/localhost:${PORT_VMESS}/http:\/\/localhost:${NEW_PORT}/g" /etc/systemd/system/cloudflared.service
            systemctl daemon-reload && systemctl restart cloudflared sing-box
            open_port "${NEW_PORT}"
            echo -e "\033[0;32m✅ VMess 端口及 Argo 临时隧道已无缝对齐同步修改！\033[0m"
        fi
        ;;
    9)
        echo -e "Cloudflare 支持的回源端口： [1] 2053  [2] 2083  [3] 2087  [4] 2096  [5] 8443"
        read -p "👉 请选择新的VMess CDN端口编号 (当前: ${PORT_VMESS_CDN}): " NEW_CDN_CHOICE
        case "$NEW_CDN_CHOICE" in
            1) NEW_CDN_PORT=2053 ;;
            2) NEW_CDN_PORT=2083 ;;
            3) NEW_CDN_PORT=2087 ;;
            4) NEW_CDN_PORT=2096 ;;
            5) NEW_CDN_PORT=8443 ;;
            *) NEW_CDN_PORT="" ;;
        esac
        if [[ "$NEW_CDN_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_VMESS_CDN}/\"listen_port\": ${NEW_CDN_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_VMESS_CDN=\"${PORT_VMESS_CDN}\"/PORT_VMESS_CDN=\"${NEW_CDN_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ VMess 套CDN端口已成功修改为 ${NEW_CDN_PORT}！请同步到 Cloudflare 该域名的对应回源设置。\033[0m"
            systemctl restart sing-box
            open_port "${NEW_CDN_PORT}"
        fi
        ;;
    10)
        read -p "👉 请输入已在 Cloudflare 开启橙云代理的CDN域名 (当前: ${CDN_DOMAIN:-未绑定}): " NEW_CDN_DOMAIN
        if [ -n "$NEW_CDN_DOMAIN" ]; then
            NEW_CDN_DOMAIN=$(echo "$NEW_CDN_DOMAIN" | tr -d ' ')
            if [ -n "$CDN_DOMAIN" ]; then
                sed -i "s/CDN_DOMAIN=\"${CDN_DOMAIN}\"/CDN_DOMAIN=\"${NEW_CDN_DOMAIN}\"/g" /etc/sing-box/meta_env.sh
            else
                echo "CDN_DOMAIN=\"${NEW_CDN_DOMAIN}\"" >> /etc/sing-box/meta_env.sh
            fi
            echo -e "\033[0;32m✅ CDN域名已绑定为 ${NEW_CDN_DOMAIN}！VMess套CDN与VLESS-WS-TLS套CDN共用该域名。请确认已在 Cloudflare 开启橙云代理并指向本机IP。\033[0m"
        fi
        ;;
    11)
        echo -e "Cloudflare 支持的回源端口： [1] 443  [2] 2053  [3] 2083  [4] 2087  [5] 2096  [6] 8443"
        read -p "👉 请选择新的VLESS-WS-TLS CDN端口编号 (当前: ${PORT_VLESS_WS_CDN}): " NEW_VLESS_CDN_CHOICE
        case "$NEW_VLESS_CDN_CHOICE" in
            1) NEW_VLESS_CDN_PORT=443 ;;
            2) NEW_VLESS_CDN_PORT=2053 ;;
            3) NEW_VLESS_CDN_PORT=2083 ;;
            4) NEW_VLESS_CDN_PORT=2087 ;;
            5) NEW_VLESS_CDN_PORT=2096 ;;
            6) NEW_VLESS_CDN_PORT=8443 ;;
            *) NEW_VLESS_CDN_PORT="" ;;
        esac
        if [[ "$NEW_VLESS_CDN_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_VLESS_WS_CDN}/\"listen_port\": ${NEW_VLESS_CDN_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_VLESS_WS_CDN=\"${PORT_VLESS_WS_CDN}\"/PORT_VLESS_WS_CDN=\"${NEW_VLESS_CDN_PORT}\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ VLESS-WS-TLS 套CDN端口已成功修改为 ${NEW_VLESS_CDN_PORT}！请同步到 Cloudflare 该域名的对应回源设置。\033[0m"
            systemctl restart sing-box
            open_port "${NEW_VLESS_CDN_PORT}"
        fi
        ;;
    12)
        read -p "👉 请输入全新的 VLESS Argo 本地端口 (仅127.0.0.1，当前: ${PORT_VLESS_ARGO}): " NEW_PORT
        if [[ "$NEW_PORT" =~ ^[0-9]+$ ]]; then
            sed -i "s/\"listen_port\": ${PORT_VLESS_ARGO}/\"listen_port\": ${NEW_PORT}/g" /etc/sing-box/config.json
            sed -i "s/PORT_VLESS_ARGO=\"${PORT_VLESS_ARGO}\"/PORT_VLESS_ARGO=\"${NEW_PORT}\"/g" /etc/sing-box/meta_env.sh
            sed -i "s/http:\/\/localhost:${PORT_VLESS_ARGO}/http:\/\/localhost:${NEW_PORT}/g" /etc/systemd/system/cloudflared-vless.service
            systemctl daemon-reload && systemctl restart cloudflared-vless sing-box
            echo -e "\033[0;32m✅ VLESS Argo 本地端口及临时隧道已同步修改！（该端口仅本机监听，无需放行防火墙）\033[0m"
            echo -e "\033[0;33mℹ️  若已绑定固定域名 [13]，请记得同步更新 CF Zero Trust 后台该 Public Hostname 指向的端口！\033[0m"
        fi
        ;;
    13)
        read -p "👉 请输入 VLESS 固定隧道二级域名 (当前: ${USER_DOMAIN_VLESS:-未绑定}): " NEW_DOMAIN_VLESS
        if [ -n "$NEW_DOMAIN_VLESS" ]; then
            NEW_DOMAIN_VLESS=$(echo "$NEW_DOMAIN_VLESS" | tr -d ' ')
            if [ -n "$USER_DOMAIN_VLESS" ]; then
                sed -i "s/USER_DOMAIN_VLESS=\"${USER_DOMAIN_VLESS}\"/USER_DOMAIN_VLESS=\"${NEW_DOMAIN_VLESS}\"/g" /etc/sing-box/meta_env.sh
            else
                echo "USER_DOMAIN_VLESS=\"${NEW_DOMAIN_VLESS}\"" >> /etc/sing-box/meta_env.sh
            fi
            echo -e "\033[0;32m✅ VLESS 固定隧道域名已绑定为 ${NEW_DOMAIN_VLESS}！\033[0m"
            echo -e "\033[0;33mℹ️  请到 CF Zero Trust 后台给你的 Tunnel 新增一条 Public Hostname：${NEW_DOMAIN_VLESS} -> http://localhost:${PORT_VLESS_ARGO}，保存后即可生效。\033[0m"
        fi
        ;;
    14)
        read -p "👉 请输入全新的伪装 SNI 域名 (当前: ${SNI_DOMAIN:-www.bing.com}，建议使用真实可访问的知名网站域名): " NEW_SNI
        if [ -n "$NEW_SNI" ]; then
            NEW_SNI=$(echo "$NEW_SNI" | tr -d ' ')
            OLD_SNI="${SNI_DOMAIN:-www.bing.com}"
            sed -i "s/${OLD_SNI//./\\.}/${NEW_SNI}/g" /etc/sing-box/config.json
            if [ -n "$SNI_DOMAIN" ]; then
                sed -i "s/SNI_DOMAIN=\"${SNI_DOMAIN}\"/SNI_DOMAIN=\"${NEW_SNI}\"/g" /etc/sing-box/meta_env.sh
            else
                echo "SNI_DOMAIN=\"${NEW_SNI}\"" >> /etc/sing-box/meta_env.sh
            fi
            openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/sing-box/server.key -out /etc/sing-box/server.crt -subj "/CN=${NEW_SNI}" -days 36500 2>/dev/null
            echo -e "\033[0;32m✅ 伪装 SNI 已更新为 ${NEW_SNI}，证书 CN 已同步重新生成！\033[0m"
            echo -e "\033[0;33mℹ️  注意：所有客户端配置里 Reality/TLS 的 sni/peer 字段都需要同步改为 ${NEW_SNI}，可运行 show-nodes 获取最新节点链接。\033[0m"
            systemctl restart sing-box
        fi
        ;;
    6)
        # 🌐 手术刀修改固定域名（即使以前是跳过模式也能在这里直接激活）
        read -p "👉 请输入你全新的固定二级域名 (例如: newvmes.yourdomain.com): " NEW_DOMAIN
        if [ -n "$NEW_DOMAIN" ]; then
            NEW_DOMAIN=$(echo "$NEW_DOMAIN" | tr -d ' ')
            sed -i "s/USER_DOMAIN=\"${USER_DOMAIN}\"/USER_DOMAIN=\"${NEW_DOMAIN}\"/g" /etc/sing-box/meta_env.sh
            sed -i "s/ENABLE_ZT=\"false\"/ENABLE_ZT=\"true\"/g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ 固定域名已在元数据中同步更改！\033[0m"
            
            # 判断并热更新或创建固定隧道系统服务
            source /etc/sing-box/meta_env.sh
            if [ -n "$USER_TOKEN" ]; then
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
                echo -e "\033[0;32m✅ 零信任固定隧道后台服务已热启动！\033[0m"
            else
                echo -e "\033[0;33mℹ️  提示：域名已设好，但由于你没输 Token，请返回菜单按 [7] 填入 Token 激活隧道！\033[0m"
            fi
        fi
        ;;
    7)
        # 🔑 手术刀修改或者现场补充 Token
        read -p "👉 请粘贴你全新的 Cloudflare 零信任长 Token: " NEW_TOKEN
        if [ -n "$NEW_TOKEN" ]; then
            NEW_TOKEN=$(echo "$NEW_TOKEN" | tr -d ' ')
            # 使用特殊的分隔符防止 Token 内部有斜杠导致 sed 瘫痪
            sed -i "s|USER_TOKEN=\"${USER_TOKEN}\"|USER_TOKEN=\"${NEW_TOKEN}\"|g" /etc/sing-box/meta_env.sh
            echo -e "\033[0;32m✅ Token 密钥已在后台安全重置！\033[0m"
            
            source /etc/sing-box/meta_env.sh
            if [ -n "$USER_DOMAIN" ] && [ "$USER_DOMAIN" != " " ]; then
                sed -i "s/ENABLE_ZT=\"false\"/ENABLE_ZT=\"true\"/g" /etc/sing-box/meta_env.sh
cat << CLOUDFLAREDZTEOF > /etc/systemd/system/cloudflared-zt.service
[Unit]
Description=cloudflare zero trust tunnel
After=network.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${NEW_TOKEN}
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
CLOUDFLAREDZTEOF
                systemctl daemon-reload && systemctl restart cloudflared-zt && systemctl enable cloudflared-zt
                echo -e "\033[0;32m✅ 零信任固定隧道已使用新 Token 全力冲锋！\033[0m"
            else
                echo -e "\033[0;33mℹ️  提示：Token 已存入，请返回菜单按 [6] 绑定二级域名以彻底激活！\033[0m"
            fi
        fi
        ;;
    *)
        echo -e "\033[0;36m👋 安全退出面板。\033[0m" && exit 0
        ;;
esac

sleep 1
show-nodes
PORTPANEL
chmod +x /usr/local/bin/port

# 首次自动呼出专属面板快照
show-nodes
EOF
chmod +x install_max_matrix.sh
./install_max_matrix.sh
