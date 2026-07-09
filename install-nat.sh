#!/bin/bash
# sing-box 极限内存版 - 64MB RAM / NAT VPS / OpenVZ·LXC
# set -e 已移除：改为显式错误检查，防止无关命令失败退出整脚本
RED='\033[0;31m';GRN='\033[0;32m';YLW='\033[0;33m';CYN='\033[0;36m';BLD='\033[1m';NC='\033[0m'
die() { echo -e "\n${RED}❌ $*${NC}\n"; exit 1; }
info(){ echo -e "${CYN}▸ $*${NC}"; }
ok()  { echo -e "${GRN}✅ $*${NC}"; }
warn(){ echo -e "${YLW}⚠  $*${NC}"; }
[ "$(id -u)" -eq 0 ] || die "请用 root 运行"
clear
echo -e "${BLD}${GRN}"
echo "╔══════════════════════════════════════════════╗"
echo "║  sing-box 极限内存版  四协议 NAT VPS        ║"
echo "║  64MB RAM / OpenVZ·LXC 全兼容               ║"
echo "╚══════════════════════════════════════════════╝${NC}"

MEM_MB=$(free -m|awk '/^Mem:/{print $2}')
SWAP_MB=$(free -m|awk '/^Swap:/{print $2}')
DISK_MB=$(df -Pm /|awk 'NR==2{print $4}')
info "RAM ${MEM_MB}MB + Swap ${SWAP_MB}MB | 磁盘可用 ${DISK_MB}MB"

info "释放系统缓存..."
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null||true
for svc in apt-daily apt-daily-upgrade unattended-upgrades; do
    systemctl stop "$svc" 2>/dev/null||true
done
journalctl --vacuum-size=1M 2>/dev/null||true
FREE_NOW=$(free -m|awk '/^Mem:/{print $7}')
info "当前可用内存: ${FREE_NOW}MB"

for cmd in wget curl openssl tar; do
    command -v "$cmd" >/dev/null 2>&1 || die "缺少 $cmd，请先: apt-get install -y $cmd"
done

gen_uuid(){
    local h; h=$(openssl rand -hex 16)
    printf '%s-%s-4%s-%x%s-%s' \
        "${h:0:8}" "${h:8:4}" "${h:12:3}" \
        $(( (0x${h:15:1}&0x3)|0x8 )) "${h:16:3}" "${h:19:12}"
}

echo ""
echo -e "${BLD}──── 步骤 1/4 : 端口配置 ────${NC}"
echo -e "${YLW}NAT VPS 请确认以下端口已在服务商控制台映射转发${NC}"
read -p "VMess-WS Argo 内部端口 [8080]: "   VMESS_PORT;   VMESS_PORT=${VMESS_PORT:-8080}
read -p "TUIC v5 端口           [26522]: "  TUIC_PORT;    TUIC_PORT=${TUIC_PORT:-26522}
read -p "VLESS-Reality 端口     [26523]: "  REALITY_PORT; REALITY_PORT=${REALITY_PORT:-26523}
read -p "VLESS-WS-TLS CDN 端口 [2053]: "   CDN_PORT;     CDN_PORT=${CDN_PORT:-2053}
read -p "NAT 对外公网 IP (留空自动探测): "  MANUAL_IP
REALITY_SNI="www.bing.com"; LISTEN="0.0.0.0"

echo ""
echo -e "${BLD}──── 步骤 2/4 : Cloudflare Argo 隧道 ────${NC}"
echo -e "${CYN}CF Zero Trust → Networks → Tunnels → 创建 → 复制 Token${NC}"
read -p "Tunnel Token (留空后填): "     CF_TOKEN
read -p "Argo 绑定域名 (留空后填): "   ARGO_DOMAIN

echo ""
echo -e "${BLD}──── 步骤 3/4 : CDN 节点（可选）────${NC}"
read -p "CDN 代理域名 (留空跳过): " CDN_DOMAIN
CDN_PATH_IN=""
[ -n "$CDN_DOMAIN" ] && read -p "WS 路径 (留空随机): " CDN_PATH_IN

echo ""
echo -e "${BLD}──── 步骤 4/4 : 下载安装 ────${NC}"

SB_VER="1.13.14"
SB_PKG="sing-box-${SB_VER}-linux-amd64.tar.gz"
SB_BIN="sing-box-${SB_VER}-linux-amd64/sing-box"
info "[1/4] 流式下载 sing-box（wget|tar 管道，不落临时文件）..."
rm -f /usr/local/bin/sing-box
DL=0
for url in \
    "https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://ghp.ci/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://mirror.ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}"; do
    info "  尝试: $url"
    if wget -q --tries=2 --timeout=60 -O- "$url" 2>/dev/null \
        | tar -zxf- -C /usr/local/bin --strip-components=1 "$SB_BIN" 2>/dev/null; then
        DL=1; break
    fi
done
if [ "$DL" -eq 0 ]; then
    warn "管道模式失败，改用磁盘缓存..."
    TMP=/tmp/sb.tar.gz
    for url in \
        "https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
        "https://ghp.ci/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
        "https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}"; do
        wget -q --tries=2 --timeout=90 "$url" -O "$TMP" 2>/dev/null && [ -s "$TMP" ] && break; rm -f "$TMP"
    done
    [ -s "$TMP" ] || die "所有镜像下载失败"
    tar -zxf "$TMP" -C /usr/local/bin --strip-components=1 "$SB_BIN"; rm -f "$TMP"
fi
chmod +x /usr/local/bin/sing-box
ok "sing-box 安装完成"

info "[2/4] 下载 cloudflared..."
CF_OK=0
for url in \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    "https://ghp.ci/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    "https://ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"; do
    wget -q --tries=2 --timeout=90 "$url" -O /usr/local/bin/cloudflared 2>/dev/null \
        && [ -s /usr/local/bin/cloudflared ] && { CF_OK=1; break; }
    rm -f /usr/local/bin/cloudflared
done
[ "$CF_OK" -eq 1 ] && { chmod +x /usr/local/bin/cloudflared; ok "cloudflared 安装完成"; } \
    || warn "cloudflared 下载失败，VMess Argo 暂不可用"

info "[3/4] 生成密钥..."
mkdir -p /etc/sing-box
UUID=$(gen_uuid)
VMESS_PATH="/$(openssl rand -hex 5)"
CDN_PATH="/${CDN_PATH_IN:-$(openssl rand -hex 5)}"; CDN_PATH="/${CDN_PATH#/}"
SUID=$(openssl rand -hex 8)
RKEYS=$(/usr/local/bin/sing-box generate reality-keypair 2>/dev/null||true)
PRIV_KEY=$(printf '%s' "$RKEYS"|awk '/PrivateKey/{print $2}')
PUB_KEY=$(printf '%s' "$RKEYS"|awk '/PublicKey/{print $2}')
[ -z "$PRIV_KEY" ] && { PRIV_KEY=$(openssl rand -base64 32|tr -d '\n='); PUB_KEY=$(openssl rand -base64 32|tr -d '\n='); }
if [ -n "$MANUAL_IP" ]; then IP4="$MANUAL_IP"
else
    IP4=""
    for api in "https://api.ipify.org" "https://ip.sb" "https://ifconfig.me"; do
        IP4=$(curl -s --max-time 6 -4 "$api" 2>/dev/null|tr -d '[:space:]') && [ -n "$IP4" ] && break
    done
    [ -z "$IP4" ] && IP4="<请填写公网IP>"
fi
openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
    -keyout /etc/sing-box/server.key -out /etc/sing-box/server.crt \
    -subj "/CN=${REALITY_SNI}" -days 36500 2>/dev/null

_write_config(){
    local cdn=""
    [ -n "$CDN_DOMAIN" ] && cdn=",
    {\"type\":\"vless\",\"tag\":\"vless-cdn\",
     \"listen\":\"${LISTEN}\",\"listen_port\":${CDN_PORT},
     \"users\":[{\"uuid\":\"${UUID}\"}],
     \"transport\":{\"type\":\"ws\",\"path\":\"${CDN_PATH}\"},
     \"tls\":{\"enabled\":true,\"server_name\":\"${CDN_DOMAIN}\",
       \"certificate_path\":\"/etc/sing-box/server.crt\",
       \"key_path\":\"/etc/sing-box/server.key\"}}"
    cat > /etc/sing-box/config.json << CFGEOF
{"log":{"level":"warn"},
 "inbounds":[
  {"type":"vmess","tag":"vmess-argo","listen":"127.0.0.1","listen_port":${VMESS_PORT},
   "users":[{"uuid":"${UUID}","alterId":0}],
   "transport":{"type":"ws","path":"${VMESS_PATH}"}},
  {"type":"tuic","tag":"tuic5","listen":"${LISTEN}","listen_port":${TUIC_PORT},
   "users":[{"uuid":"${UUID}","password":"${UUID}"}],
   "congestion_control":"bbr",
   "tls":{"enabled":true,"alpn":["h3"],
     "certificate_path":"/etc/sing-box/server.crt",
     "key_path":"/etc/sing-box/server.key"}},
  {"type":"vless","tag":"vless-reality","listen":"${LISTEN}","listen_port":${REALITY_PORT},
   "users":[{"uuid":"${UUID}","flow":"xtls-rprx-vision"}],
   "tls":{"enabled":true,"server_name":"${REALITY_SNI}",
     "reality":{"enabled":true,
       "handshake":{"server":"${REALITY_SNI}","server_port":443},
       "private_key":"${PRIV_KEY}",
       "short_id":["${SUID}"]}}}${cdn}
 ],
 "outbounds":[{"type":"direct"}]}
CFGEOF
}
_write_config

cat > /etc/sing-box/node.conf << NODEEOF
UUID=${UUID}
PUB_KEY=${PUB_KEY}
PRIV_KEY=${PRIV_KEY}
SUID=${SUID}
VMESS_PORT=${VMESS_PORT}
VMESS_PATH=${VMESS_PATH}
TUIC_PORT=${TUIC_PORT}
REALITY_PORT=${REALITY_PORT}
REALITY_SNI=${REALITY_SNI}
CDN_PORT=${CDN_PORT}
CDN_PATH=${CDN_PATH}
CDN_DOMAIN=${CDN_DOMAIN}
ARGO_DOMAIN=${ARGO_DOMAIN}
CF_TOKEN=${CF_TOKEN}
IP4=${IP4}
LISTEN=${LISTEN}
NODEEOF
chmod 600 /etc/sing-box/node.conf

for proto_port in "tcp:$REALITY_PORT" "udp:$TUIC_PORT"; do
    p="${proto_port%%:*}"; port="${proto_port##*:}"
    command -v iptables>/dev/null 2>&1 && { iptables -C INPUT -p "$p" --dport "$port" -j ACCEPT 2>/dev/null||iptables -I INPUT -p "$p" --dport "$port" -j ACCEPT 2>/dev/null||true; }
    command -v ufw>/dev/null 2>&1 && ufw status 2>/dev/null|grep -q active && ufw allow "${port}/${p}" >/dev/null 2>&1||true
done
[ -n "$CDN_DOMAIN" ] && { command -v iptables>/dev/null 2>&1 && { iptables -C INPUT -p tcp --dport "$CDN_PORT" -j ACCEPT 2>/dev/null||iptables -I INPUT -p tcp --dport "$CDN_PORT" -j ACCEPT 2>/dev/null||true; }; }

info "[4/4] 注册服务..."
cat > /etc/systemd/system/sing-box.service << 'SVCEOF'
[Unit]
Description=sing-box
After=network.target
[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=8s
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable sing-box>/dev/null 2>&1
systemctl restart sing-box && ok "sing-box 已启动" || warn "sing-box 启动失败: journalctl -u sing-box -n 20"

if [ -n "$CF_TOKEN" ] && [ -f /usr/local/bin/cloudflared ]; then
    cat > /etc/systemd/system/cloudflared.service << CFSEOF
[Unit]
Description=cloudflared tunnel
After=network.target
[Service]
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate run --token ${CF_TOKEN}
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
CFSEOF
    systemctl daemon-reload
    systemctl enable cloudflared>/dev/null 2>&1
    systemctl restart cloudflared && ok "cloudflared 已启动" || warn "cloudflared 启动失败"
fi

cat > /usr/local/bin/node << 'PANELEOF'
#!/bin/bash
CONF=/etc/sing-box/node.conf
[ -f "$CONF" ] || { echo "未找到配置: $CONF"; exit 1; }
. "$CONF"
RED='\033[0;31m';GRN='\033[0;32m';YLW='\033[0;33m';CYN='\033[0;36m';BLD='\033[1m';NC='\033[0m'

_gen_uuid(){
    local h; h=$(openssl rand -hex 16)
    printf '%s-%s-4%s-%x%s-%s' "${h:0:8}" "${h:8:4}" "${h:12:3}" \
        $(( (0x${h:15:1}&0x3)|0x8 )) "${h:16:3}" "${h:19:12}"
}

_save(){
    cat > "$CONF" << SAVEEOF
UUID=${UUID}
PUB_KEY=${PUB_KEY}
PRIV_KEY=${PRIV_KEY}
SUID=${SUID}
VMESS_PORT=${VMESS_PORT}
VMESS_PATH=${VMESS_PATH}
TUIC_PORT=${TUIC_PORT}
REALITY_PORT=${REALITY_PORT}
REALITY_SNI=${REALITY_SNI}
CDN_PORT=${CDN_PORT}
CDN_PATH=${CDN_PATH}
CDN_DOMAIN=${CDN_DOMAIN}
ARGO_DOMAIN=${ARGO_DOMAIN}
CF_TOKEN=${CF_TOKEN}
IP4=${IP4}
LISTEN=${LISTEN}
SAVEEOF
    chmod 600 "$CONF"
}

_write_config(){
    local cdn=""
    [ -n "$CDN_DOMAIN" ] && cdn=",
    {\"type\":\"vless\",\"tag\":\"vless-cdn\",
     \"listen\":\"${LISTEN}\",\"listen_port\":${CDN_PORT},
     \"users\":[{\"uuid\":\"${UUID}\"}],
     \"transport\":{\"type\":\"ws\",\"path\":\"${CDN_PATH}\"},
     \"tls\":{\"enabled\":true,\"server_name\":\"${CDN_DOMAIN}\",
       \"certificate_path\":\"/etc/sing-box/server.crt\",
       \"key_path\":\"/etc/sing-box/server.key\"}}"
    cat > /etc/sing-box/config.json << CFGEOF
{"log":{"level":"warn"},
 "inbounds":[
  {"type":"vmess","tag":"vmess-argo","listen":"127.0.0.1","listen_port":${VMESS_PORT},
   "users":[{"uuid":"${UUID}","alterId":0}],
   "transport":{"type":"ws","path":"${VMESS_PATH}"}},
  {"type":"tuic","tag":"tuic5","listen":"${LISTEN}","listen_port":${TUIC_PORT},
   "users":[{"uuid":"${UUID}","password":"${UUID}"}],
   "congestion_control":"bbr",
   "tls":{"enabled":true,"alpn":["h3"],
     "certificate_path":"/etc/sing-box/server.crt",
     "key_path":"/etc/sing-box/server.key"}},
  {"type":"vless","tag":"vless-reality","listen":"${LISTEN}","listen_port":${REALITY_PORT},
   "users":[{"uuid":"${UUID}","flow":"xtls-rprx-vision"}],
   "tls":{"enabled":true,"server_name":"${REALITY_SNI}",
     "reality":{"enabled":true,
       "handshake":{"server":"${REALITY_SNI}","server_port":443},
       "private_key":"${PRIV_KEY}",
       "short_id":["${SUID}"]}}}${cdn}
 ],
 "outbounds":[{"type":"direct"}]}
CFGEOF
}

_reload(){ _save; _write_config; systemctl restart sing-box; echo -e "${GRN}✅ 已重启${NC}"; }

_show_nodes(){
    clear
    echo -e "${BLD}${GRN}╔══════════════════════════════════════════════════╗"
    echo    "║                  📡  节点信息                   ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    echo -e "  IP:${BLD}${IP4}${NC}  UUID:${BLD}${UUID}${NC}"
    echo ""
    echo -e "${CYN}━━ 1 ▸ VMess+WS+TLS（Argo固定隧道）━━━━━━━━━━━━━━━${NC}"
    if [ -n "$ARGO_DOMAIN" ]; then
        VJ="{\"v\":\"2\",\"ps\":\"Argo-VMess\",\"add\":\"${ARGO_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${VMESS_PATH}\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\"}"
        echo -e " ${YLW}vmess://$(printf '%s' "$VJ"|base64 -w0)${NC}"
        echo -e " 域名:${ARGO_DOMAIN}  路径:${VMESS_PATH}  端口:443"
        echo -e " ${CYN}→ CF Public Hostname: Service=http://127.0.0.1:${VMESS_PORT}${NC}"
    else
        echo -e " ${RED}⚠ 未设置Argo域名 → 选[3]填写${NC}"
    fi
    echo ""
    echo -e "${CYN}━━ 2 ▸ VLESS+WS+TLS（CDN）━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -n "$CDN_DOMAIN" ]; then
        echo -e " ${YLW}vless://${UUID}@${CDN_DOMAIN}:${CDN_PORT}?encryption=none&security=tls&sni=${CDN_DOMAIN}&type=ws&host=${CDN_DOMAIN}&path=${CDN_PATH}#CDN-VLESS${NC}"
        echo -e " ${CYN}CF SSL模式设为Full（非Full Strict）${NC}"
    else
        echo -e " ${RED}⚠ 未设置CDN域名 → 选[4]填写${NC}"
    fi
    echo ""
    echo -e "${CYN}━━ 3 ▸ TUIC v5  UDP:${TUIC_PORT}  ━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${YLW}tuic://${UUID}:${UUID}@${IP4}:${TUIC_PORT}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=1&alpn=h3&sni=${REALITY_SNI}#TUIC5${NC}"
    echo -e " ${CYN}客户端ALPN必须填 h3，跳过证书验证${NC}"
    echo ""
    echo -e "${CYN}━━ 4 ▸ VLESS+Reality  TCP:${REALITY_PORT}  ━━━━━━━━━━━━━━━━${NC}"
    echo -e " ${YLW}vless://${UUID}@${IP4}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Reality${NC}"
    echo ""
}

_show_status(){
    clear
    echo -e "${BLD}── 服务状态 ────────────────────────────────────────${NC}"
    for s in sing-box cloudflared; do
        systemctl is-active --quiet "$s" 2>/dev/null \
            && echo -e "  ${s}: ${GRN}● 运行中${NC}" \
            || echo -e "  ${s}: ${RED}● 未运行${NC}"
    done
    echo ""
    echo -e "${BLD}── 监听端口 ────────────────────────────────────────${NC}"
    ss -tulpn 2>/dev/null|grep sing-box||echo "  未见端口（服务未运行？）"
    echo ""
    echo -e "${BLD}── 日志（最近20行）────────────────────────────────${NC}"
    journalctl -u sing-box --no-pager -n 20 2>/dev/null||echo "  无日志"
}

_uninstall(){
    echo -e "${RED}⚠ 将彻底删除 sing-box/cloudflared 及所有配置！${NC}"
    read -p "输入 yes 确认: " C; [ "$C" = "yes" ]||{ echo 已取消; return; }
    systemctl stop sing-box cloudflared 2>/dev/null||true
    systemctl disable sing-box cloudflared 2>/dev/null||true
    rm -f /etc/systemd/system/sing-box.service /etc/systemd/system/cloudflared.service
    systemctl daemon-reload
    command -v iptables>/dev/null 2>&1 && {
        iptables -D INPUT -p tcp --dport "$REALITY_PORT" -j ACCEPT 2>/dev/null||true
        iptables -D INPUT -p udp --dport "$TUIC_PORT"    -j ACCEPT 2>/dev/null||true
        [ -n "$CDN_DOMAIN" ]&&iptables -D INPUT -p tcp --dport "$CDN_PORT" -j ACCEPT 2>/dev/null||true
    }
    rm -f /usr/local/bin/sing-box /usr/local/bin/cloudflared
    rm -rf /etc/sing-box
    rm -f /usr/local/bin/node
    echo -e "${GRN}✅ 卸载完成。CF后台Tunnel请手动删除。${NC}"; exit 0
}

while true; do
    clear
    echo -e "${BLD}${GRN}╔══════════════════════════════════════════════════╗"
    echo    "║       sing-box 管理面板   输入数字后回车         ║"
    echo    "╠══════════════════════════════════════════════════╣"
    echo -e "║  1  查看所有节点信息 & 链接                     ║"
    echo -e "║  2  查看服务状态 & 日志                         ║"
    echo -e "║  3  设置/修改 Argo 域名（VMess节点）            ║"
    echo -e "║  4  设置/修改 CDN 域名（VLESS-WS-TLS节点）      ║"
    echo -e "║  5  更换 UUID（所有协议同步）                   ║"
    echo -e "║  6  修改端口（TUIC/Reality/CDN/VMess）          ║"
    echo -e "║  7  修改服务器公网 IP                           ║"
    echo -e "║  8  重启 sing-box / cloudflared                 ║"
    echo -e "║  9  卸载（删除所有组件与配置）                  ║"
    echo -e "║  0  退出面板                                    ║"
    echo -e "╚══════════════════════════════════════════════════╝${NC}"
    read -p "  ❯ " OPT
    case "$OPT" in
        1) _show_nodes; read -p "回车返回..." _;;
        2) _show_status; read -p "回车返回..." _;;
        3) read -p "Argo域名(当前:${ARGO_DOMAIN:-未设置}): " v; [ -n "$v" ]&&ARGO_DOMAIN="$v"; _save
           echo -e "${GRN}已保存。去CF确认Public Hostname→Service:http://127.0.0.1:${VMESS_PORT}${NC}"
           read -p "回车继续..." _;;
        4) read -p "CDN域名(当前:${CDN_DOMAIN:-未设置}): " v; [ -n "$v" ]&&CDN_DOMAIN="$v"
           read -p "WS路径(当前:${CDN_PATH},回车不改): " v; [ -n "$v" ]&&CDN_PATH="/${v#/}"
           read -p "端口(当前:${CDN_PORT},回车不改): " v; [ -n "$v" ]&&CDN_PORT="$v"
           _reload; read -p "回车继续..." _;;
        5) read -p "新UUID(回车随机): " v; UUID=${v:-$(_gen_uuid)}; _reload
           echo -e "新UUID:${BLD}${UUID}${NC}"; read -p "回车继续..." _;;
        6) read -p "TUIC端口(当前:${TUIC_PORT}): " v; [ -n "$v" ]&&TUIC_PORT="$v"
           read -p "Reality端口(当前:${REALITY_PORT}): " v; [ -n "$v" ]&&REALITY_PORT="$v"
           read -p "CDN端口(当前:${CDN_PORT}): " v; [ -n "$v" ]&&CDN_PORT="$v"
           read -p "VMess内部端口(当前:${VMESS_PORT}): " v; [ -n "$v" ]&&VMESS_PORT="$v"
           _reload; read -p "回车继续..." _;;
        7) read -p "公网IP(当前:${IP4}): " v; [ -n "$v" ]&&IP4="$v"; _save
           echo -e "${GRN}已保存${NC}"; read -p "回车继续..." _;;
        8) systemctl restart sing-box&&echo -e "${GRN}sing-box已重启${NC}"||echo -e "${RED}重启失败${NC}"
           [ -f /usr/local/bin/cloudflared ]&&systemctl restart cloudflared 2>/dev/null&&echo -e "${GRN}cloudflared已重启${NC}"||true
           read -p "回车继续..." _;;
        9) _uninstall;;
        0|q|Q) echo 退出; exit 0;;
        *) echo -e "${RED}无效${NC}"; sleep 1;;
    esac
done
PANELEOF
chmod +x /usr/local/bin/node

# 验证配置文件语法
if /usr/local/bin/sing-box check -c /etc/sing-box/config.json 2>/dev/null; then
    ok "sing-box 配置验证通过"
else
    warn "配置可能有问题，查看: /usr/local/bin/sing-box check -c /etc/sing-box/config.json"
fi
sleep 2; clear
SB_ST=$(systemctl is-active sing-box 2>/dev/null||echo inactive)
CF_ST=$(systemctl is-active cloudflared 2>/dev/null||echo inactive)
echo -e "${BLD}${GRN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║             🎉  安装完成！                      ║"
echo "╚══════════════════════════════════════════════════╝${NC}"
echo -e "  sing-box   :$([ "$SB_ST" = "active" ]&&echo " ${GRN}● 运行中${NC}"||echo " ${RED}● 未运行 → journalctl -u sing-box -n 30${NC}")"
echo -e "  cloudflared:$([ "$CF_ST" = "active" ]&&echo " ${GRN}● 运行中${NC}"||echo " ${YLW}● 未运行(Token空/下载失败)${NC}")"
echo ""
echo -e "${CYN}━━ 1 ▸ VMess+Argo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -n "$ARGO_DOMAIN" ]; then
    VJ="{\"v\":\"2\",\"ps\":\"Argo-VMess\",\"add\":\"${ARGO_DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${VMESS_PATH}\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\"}"
    echo -e " ${YLW}vmess://$(printf '%s' "$VJ"|base64 -w0)${NC}"
else
    echo -e " ${RED}未设置Argo域名 → 输入 node 选3 填写${NC}"
fi
echo ""
echo -e "${CYN}━━ 2 ▸ VLESS+CDN ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -n "$CDN_DOMAIN" ]; then
    echo -e " ${YLW}vless://${UUID}@${CDN_DOMAIN}:${CDN_PORT}?encryption=none&security=tls&sni=${CDN_DOMAIN}&type=ws&host=${CDN_DOMAIN}&path=${CDN_PATH}#CDN-VLESS${NC}"
else
    echo -e " ${RED}未设置CDN域名 → 输入 node 选4 填写${NC}"
fi
echo ""
echo -e "${CYN}━━ 3 ▸ TUIC v5  UDP:${TUIC_PORT}  ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YLW}tuic://${UUID}:${UUID}@${IP4}:${TUIC_PORT}?congestion_control=bbr&udp_relay_mode=native&allow_insecure=1&alpn=h3&sni=${REALITY_SNI}#TUIC5${NC}"
echo ""
echo -e "${CYN}━━ 4 ▸ VLESS+Reality  TCP:${REALITY_PORT}  ━━━━━━━━━━━━━━━━━${NC}"
echo -e " ${YLW}vless://${UUID}@${IP4}:${REALITY_PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${REALITY_SNI}&fp=chrome&pbk=${PUB_KEY}&sid=${SUID}&type=tcp#Reality${NC}"
echo ""
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  管理命令：${BLD}node${NC} 回车，进入面板"
echo -e "${GRN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
