#!/bin/sh
# sing-box 极限内存版 - 128MB RAM / 5GB 磁盘 / NAT VP
# 兼容: Debian / Ubuntu (systemd)  &  Alpine (OpenRC + musl + busybox)
# 引导层用 /bin/sh(POSIX) 写，探测/安装 bash 后再把自己交给 bash 执行
# 这样即使目标机上一开始完全没有 bash 也能跑起来。
# ------------------------------------------------------------------
if [ -z "$BASH_VERSION" ]; then
    [ "$(id -u)" -eq 0 ] 2>/dev/null || { echo "请用 root 运行"; exit 1; }
    if ! command -v bash >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            apk update -q >/dev/null 2>&1
            apk add --no-cache bash >/dev/null 2>&1
        elif command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq bash >/dev/null 2>&1
        fi
    fi
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "无法自动安装 bash，请手动安装(apk add bash 或 apt-get install bash)后重试"
        exit 1
    fi
fi
# ------------------------------ 以下全部在 bash 下执行 ------------------------------
# set -e 已移除：改为显式错误检查，防止无关命令失败退出整脚本
RED='\033[0;31m';GRN='\033[0;32m';YLW='\033[0;33m';CYN='\033[0;36m';BLD='\033[1m';NC='\033[0m'
die() { echo -e "\n${RED}❌ $*${NC}\n"; exit 1; }
info(){ echo -e "${CYN}▸ $*${NC}"; }
ok()  { echo -e "${GRN}✅ $*${NC}"; }
warn(){ echo -e "${YLW}⚠  $*${NC}"; }
[ "$(id -u)" -eq 0 ] || die "请用 root 运行"

# ---------- 交互输入：强制从真实终端(/dev/tty)读取 ----------
# 关键修复：如果脚本是通过 `curl ... | bash` 管道执行的，标准输入(stdin)被
# 管道占用，此时普通的 `read` 会立刻读到 EOF/空值，导致所有问题"秒过"、
# 全部使用默认值，看起来像是"自动装完，啥也不问"。这里强制从 /dev/tty
# （也就是你键盘正在敲的那个终端）读取，无论脚本是被下载后执行、
# 还是通过管道直接执行，都能真正停下来等你输入。
if [ ! -r /dev/tty ]; then
    warn "检测不到交互终端(/dev/tty)，可能是在非交互环境(如管道/cron)中执行。"
    warn "强烈建议改为：先下载脚本到文件再执行，而不是 curl xxx | bash 这种管道方式："
    warn "  wget -O install-nat.sh <脚本地址> && chmod +x install-nat.sh && ./install-nat.sh"
fi
ask(){ # ask "提示语" 变量名
    local __prompt="$1" __var="$2"
    if [ -r /dev/tty ]; then
        read -r -p "$__prompt" "$__var" < /dev/tty
    else
        read -r -p "$__prompt" "$__var"
    fi
}

# ---------- OS / 初始化系统探测 ----------
OS_FAMILY="debian"
if [ -f /etc/alpine-release ]; then
    OS_FAMILY="alpine"
elif [ -f /etc/os-release ] && grep -qi alpine /etc/os-release 2>/dev/null; then
    OS_FAMILY="alpine"
fi

INIT_SYS="systemd"
if command -v rc-service >/dev/null 2>&1 && command -v openrc >/dev/null 2>&1; then
    INIT_SYS="openrc"
elif [ "$OS_FAMILY" = alpine ]; then
    INIT_SYS="openrc"
fi

clear
echo -e "${BLD}${GRN}"
echo "╔══════════════════════════════════════════════╗"
echo "║  sing-box 极限内存版  四协议 NAT VPS        ║"
echo "║  128MB RAM / Alpine·Debian·Ubuntu 全兼容    ║"
echo "╚══════════════════════════════════════════════╝${NC}"
info "系统识别: OS=${OS_FAMILY}  初始化系统=${INIT_SYS}"

# ---------- 依赖安装（区分包管理器） ----------
install_deps(){
    if [ "$OS_FAMILY" = alpine ]; then
        info "Alpine: 通过 apk 安装/校准依赖(强制安装完整版 wget/curl，避免 busybox 精简版参数不兼容；" \
             "同时安装 gcompat/libc6-compat，因为 sing-box/cloudflared 官方发行的 amd64 二进制是" \
             "动态链接 glibc 的，musl 系统不装这个兼容层会报'No such file or directory')..."
        apk update -q >/dev/null 2>&1
        apk add --no-cache wget curl openssl tar iproute2 ca-certificates coreutils procps openrc gcompat libc6-compat >/dev/null 2>&1
        rm -rf /var/cache/apk/* 2>/dev/null || true
    else
        local missing=""
        for cmd in wget curl openssl tar; do
            command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
        done
        if [ -n "$missing" ]; then
            info "Debian/Ubuntu: 检测到缺失依赖:${missing}，尝试 apt-get 安装..."
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq $missing >/dev/null 2>&1
        fi
    fi
    for cmd in wget curl openssl tar; do
        command -v "$cmd" >/dev/null 2>&1 || die "缺少 $cmd 且自动安装失败，请手动安装后重试"
    done
}
install_deps
ok "依赖检查通过"

# ---------- 内存 / 磁盘信息（不依赖 free，直接读 /proc/meminfo，busybox 也兼容） ----------
MEM_MB=$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
SWAP_MB=$(awk '/SwapTotal/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
DISK_MB=$(df -Pm / | awk 'NR==2{print $4}')
MEM_MB=${MEM_MB:-0}; SWAP_MB=${SWAP_MB:-0}
info "RAM ${MEM_MB}MB + Swap ${SWAP_MB}MB | 磁盘可用 ${DISK_MB}MB"

# ---------- 128MB 内存机型：如无 swap 且磁盘充足，自动开一个小 swap 防止 OOM ----------
if [ "$SWAP_MB" -eq 0 ] && [ "$MEM_MB" -le 256 ] && [ "$DISK_MB" -ge 1024 ] && [ ! -f /swapfile ]; then
    info "检测到无 Swap 且内存较小，创建 256MB Swap 文件以防 OOM（占用磁盘 256MB）..."
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l 256M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=256 2>/dev/null
    else
        dd if=/dev/zero of=/swapfile bs=1M count=256 2>/dev/null
    fi
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1 && swapon /swapfile >/dev/null 2>&1 && {
        ok "Swap 已启用"
        if [ "$OS_FAMILY" = alpine ]; then
            grep -q '^/swapfile' /etc/fstab 2>/dev/null || echo "/swapfile none swap sw 0 0" >> /etc/fstab
        else
            grep -q '^/swapfile' /etc/fstab 2>/dev/null || echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
    } || warn "Swap 创建失败，跳过（不影响后续安装）"
fi

# ---------- 释放系统缓存 ----------
info "释放系统缓存..."
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
if [ "$OS_FAMILY" != alpine ]; then
    for svc in apt-daily apt-daily-upgrade unattended-upgrades; do
        systemctl stop "$svc" 2>/dev/null || true
    done
    journalctl --vacuum-size=1M 2>/dev/null || true
fi
FREE_NOW=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
[ -z "$FREE_NOW" ] && FREE_NOW=$(awk '/MemFree/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
info "当前可用内存: ${FREE_NOW:-未知}MB"

gen_uuid(){
    local h; h=$(openssl rand -hex 16)
    printf '%s-%s-4%s-%x%s-%s' \
        "${h:0:8}" "${h:8:4}" "${h:12:3}" \
        $(( (0x${h:15:1}&0x3)|0x8 )) "${h:16:3}" "${h:19:12}"
}

echo ""
echo -e "${BLD}──── 步骤 1/4 : 端口配置 ────${NC}"
echo -e "${YLW}NAT VPS 请确认以下端口已在服务商控制台映射转发${NC}"
ask "VMess-WS Argo 内部端口 [8080]: " VMESS_PORT;   VMESS_PORT=${VMESS_PORT:-8080}
ask "TUIC v5 端口           [26522]: " TUIC_PORT;    TUIC_PORT=${TUIC_PORT:-26522}
ask "VLESS-Reality 端口     [26523]: " REALITY_PORT; REALITY_PORT=${REALITY_PORT:-26523}
ask "VLESS-WS-TLS CDN 端口 [2053]: " CDN_PORT;     CDN_PORT=${CDN_PORT:-2053}
ask "NAT 对外公网 IP (留空自动探测): " MANUAL_IP
REALITY_SNI="www.bing.com"; LISTEN="0.0.0.0"

# 端口合法性兜底校验：非数字或超范围一律回退到默认值，避免生成坏配置
_valid_port(){ case "$1" in ''|*[!0-9]*) return 1;; esac; [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }
_valid_port "$VMESS_PORT"   || { warn "VMess端口输入无效，使用默认 8080";   VMESS_PORT=8080; }
_valid_port "$TUIC_PORT"    || { warn "TUIC端口输入无效，使用默认 26522";   TUIC_PORT=26522; }
_valid_port "$REALITY_PORT" || { warn "Reality端口输入无效，使用默认 26523"; REALITY_PORT=26523; }
_valid_port "$CDN_PORT"     || { warn "CDN端口输入无效，使用默认 2053";     CDN_PORT=2053; }

echo ""
echo -e "${BLD}──── 步骤 2/4 : Cloudflare Argo 隧道 ────${NC}"
echo -e "${CYN}CF Zero Trust → Networks → Tunnels → 创建 → 复制 Token${NC}"
ask "Tunnel Token (留空后填): " CF_TOKEN
ask "Argo 绑定域名 (留空后填): " ARGO_DOMAIN

echo ""
echo -e "${BLD}──── 步骤 3/4 : CDN 节点（可选）────${NC}"
ask "CDN 代理域名 (留空跳过): " CDN_DOMAIN
CDN_PATH_IN=""
[ -n "$CDN_DOMAIN" ] && ask "WS 路径 (留空随机): " CDN_PATH_IN

echo ""
echo -e "${BLD}──── 步骤 4/4 : 下载安装 ────${NC}"

mkdir -p /usr/local/bin

# ---------- CPU 架构探测 ----------
# 之前的版本硬编码只下载 amd64，如果 VPS 实际是 ARM(常见于很多便宜 NAT/LXC/OpenVZ
# 机型)，装上的 amd64 二进制会"解压成功但无法执行"，报 exec format error。
UNAME_M=$(uname -m)
case "$UNAME_M" in
    x86_64|amd64)        SB_ARCH="amd64"; CF_ARCH="amd64";;
    aarch64|arm64)       SB_ARCH="arm64"; CF_ARCH="arm64";;
    armv7l|armv6l|armhf) SB_ARCH="armv7"; CF_ARCH="arm";;
    i386|i686)           SB_ARCH="386";   CF_ARCH="386";;
    *) die "无法识别的 CPU 架构: ${UNAME_M}，sing-box/cloudflared 官方发行版可能没有对应版本，请手动确认后处理";;
esac
info "CPU 架构: ${UNAME_M} → sing-box:${SB_ARCH}  cloudflared:${CF_ARCH}"

# sing-box 官方发布的是静态编译的 Go 二进制，musl(Alpine) / glibc(Debian) 通用，无需区分下载包
SB_VER="1.13.14"
SB_PKG="sing-box-${SB_VER}-linux-${SB_ARCH}.tar.gz"
SB_BIN="sing-box-${SB_VER}-linux-${SB_ARCH}/sing-box"
info "[1/4] 下载 sing-box..."
rm -f /usr/local/bin/sing-box
TMP=/tmp/sb.tar.gz
DL=0
for url in \
    "https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://ghp.ci/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://mirror.ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}" \
    "https://gh-proxy.com/https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}"; do
    info "  尝试: $url"
    rm -f "$TMP"
    wget -q --tries=2 --timeout=60 "$url" -O "$TMP" 2>/dev/null
    # 关键修复：不能只看文件"有没有内容"，很多镜像失败时会返回一个几十字节的
    # 报错/限流网页，文件非空但根本不是有效的 gzip 包，之前脚本没检查这个，
    # 导致"下载成功"但解压出来的东西是空的，二进制根本不存在。
    if [ -s "$TMP" ] && gzip -t "$TMP" 2>/dev/null && tar -tzf "$TMP" "$SB_BIN" >/dev/null 2>&1; then
        DL=1; break
    else
        warn "  该镜像返回内容无效（非 gzip 包或缺少目标文件），换下一个"
    fi
done
if [ "$DL" -eq 0 ]; then
    die "sing-box 所有镜像下载失败（可能是本机无法访问 GitHub 及其镜像站）。
      请手动执行以下命令下载并放到 /usr/local/bin/sing-box 后重新运行本脚本：
      wget -O /tmp/sb.tar.gz https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/${SB_PKG}"
fi
tar -zxf "$TMP" -C /usr/local/bin --strip-components=1 "$SB_BIN" || die "解压 sing-box 失败，压缩包可能已损坏"
rm -f "$TMP"
chmod +x /usr/local/bin/sing-box
if ! /usr/local/bin/sing-box version >/dev/null 2>&1 && [ "$OS_FAMILY" = alpine ]; then
    # Alpine 是 musl libc，官方发行的 amd64 二进制是动态链接 glibc 的，
    # 缺少 gcompat 兼容层时会报"No such file or directory"。这里补装一次再重试。
    warn "sing-box 首次执行失败，尝试补装 glibc 兼容层(gcompat)后重试..."
    apk add --no-cache gcompat libc6-compat >/dev/null 2>&1
fi
if [ -x /usr/local/bin/sing-box ] && /usr/local/bin/sing-box version >/dev/null 2>&1; then
    ok "sing-box 安装完成：$(/usr/local/bin/sing-box version 2>/dev/null | head -n1)"
else
    if [ "$OS_FAMILY" = alpine ]; then
        die "sing-box 二进制无法执行。已尝试安装 gcompat 仍失败，请手动执行
      apk add gcompat libc6-compat && /usr/local/bin/sing-box version
      查看具体报错（常见于 Alpine musl 缺少 glibc 兼容层，或该 Alpine 版本仓库没有 gcompat 包）"
    else
        die "sing-box 二进制解压后无法执行（架构不匹配或文件损坏），请检查后重试"
    fi
fi

info "[2/4] 下载 cloudflared..."
CF_OK=0
rm -f /usr/local/bin/cloudflared
for url in \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
    "https://ghp.ci/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
    "https://ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
    "https://gh-proxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}"; do
    rm -f /usr/local/bin/cloudflared
    wget -q --tries=2 --timeout=90 "$url" -O /usr/local/bin/cloudflared 2>/dev/null
    if [ -s /usr/local/bin/cloudflared ]; then
        chmod +x /usr/local/bin/cloudflared
        # 同样验证：能跑起来 --version 才算数，防止拿到一个错误页面当二进制用
        if /usr/local/bin/cloudflared --version >/dev/null 2>&1; then
            CF_OK=1; break
        fi
    fi
done
if [ "$CF_OK" -eq 1 ]; then
    ok "cloudflared 安装完成"
else
    rm -f /usr/local/bin/cloudflared
    warn "cloudflared 下载失败或二进制不可执行，VMess Argo 暂不可用（不影响 TUIC/Reality/CDN 节点）"
fi

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
INIT_SYS=${INIT_SYS}
OS_FAMILY=${OS_FAMILY}
NODEEOF
chmod 600 /etc/sing-box/node.conf

for proto_port in "tcp:$REALITY_PORT" "udp:$TUIC_PORT"; do
    p="${proto_port%%:*}"; port="${proto_port##*:}"
    command -v iptables>/dev/null 2>&1 && { iptables -C INPUT -p "$p" --dport "$port" -j ACCEPT 2>/dev/null||iptables -I INPUT -p "$p" --dport "$port" -j ACCEPT 2>/dev/null||true; }
    command -v ufw>/dev/null 2>&1 && ufw status 2>/dev/null|grep -q active && ufw allow "${port}/${p}" >/dev/null 2>&1||true
done
[ -n "$CDN_DOMAIN" ] && { command -v iptables>/dev/null 2>&1 && { iptables -C INPUT -p tcp --dport "$CDN_PORT" -j ACCEPT 2>/dev/null||iptables -I INPUT -p tcp --dport "$CDN_PORT" -j ACCEPT 2>/dev/null||true; }; }

info "[4/4] 注册服务..."
mkdir -p /var/log

if [ "$INIT_SYS" = openrc ]; then
    # ---------- Alpine / OpenRC ----------
    # 说明：supervise-daemon 在部分精简容器环境里状态记录会卡死("already
    # running" 但实际进程根本不存在，且清不掉)，比较不可靠。改回最基础、
    # 兼容性最好的 command_background 方式来启动，"自动重启"这件事改交给
    # 后面单独设置的 crond 看门狗脚本（每分钟检查一次，进程不在了就拉起来），
    # 两边职责拆开，任何一边有问题都不会互相拖累。
    cat > /etc/init.d/sing-box << 'SVCEOF'
#!/sbin/openrc-run
name="sing-box"
description="sing-box service"
command="/usr/local/bin/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background="yes"
output_log="/var/log/sing-box.log"
error_log="/var/log/sing-box.log"
pidfile="/run/${RC_SVC_NAME}.pid"

depend() {
    need net
}
SVCEOF
    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default >/dev/null 2>&1
    rc-service sing-box stop >/dev/null 2>&1
    pkill -9 -f "/usr/local/bin/sing-box" >/dev/null 2>&1
    rm -f /run/sing-box.pid 2>/dev/null
    rc-service sing-box zap >/dev/null 2>&1
    rc-service sing-box start >/dev/null 2>&1
    sleep 1
    if pgrep -f "/usr/local/bin/sing-box run" >/dev/null 2>&1; then
        ok "sing-box 已启动"
    else
        warn "sing-box 未能启动，查看日志: cat /var/log/sing-box.log"
        warn "现场诊断（前台试跑2秒，直接看报错原因）："
        timeout 2 /usr/local/bin/sing-box run -c /etc/sing-box/config.json 2>&1 | head -n 20
    fi
else
    # ---------- Debian / Ubuntu / systemd ----------
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
fi

if [ -n "$CF_TOKEN" ] && [ -f /usr/local/bin/cloudflared ]; then
    if [ "$INIT_SYS" = openrc ]; then
        # 不再用 /etc/init.d/cloudflared + rc-service：这套在部分精简容器
        # 环境里，OpenRC 自带的进程检测会认死理，误判"已经在运行"（很可能是
        # 通过 /proc/*/exe 匹配到某个异常/僵尸进程，而不是靠命令行匹配，
        # 所以连 pkill -f、rm pidfile、zap 这些手段都清不掉）。改用最原始的
        # nohup 后台启动方式，完全绕开 OpenRC 的进程跟踪逻辑；配合下面的
        # crond 看门狗（用 pgrep 判活，这个是准的）做自动重启。
        rm -f /etc/init.d/cloudflared 2>/dev/null
        cat > /usr/local/bin/cloudflared-start.sh << 'CFSTARTEOF'
#!/bin/sh
CONF=/etc/sing-box/node.conf
[ -f "$CONF" ] || exit 0
CF_TOKEN=$(grep '^CF_TOKEN=' "$CONF" | cut -d= -f2-)
[ -z "$CF_TOKEN" ] && exit 0
[ -x /usr/local/bin/cloudflared ] || exit 0
pgrep -f "/usr/local/bin/cloudflared tunnel" >/dev/null 2>&1 && exit 0
nohup /usr/local/bin/cloudflared tunnel --no-autoupdate run --token "$CF_TOKEN" >> /var/log/cloudflared.log 2>&1 &
disown 2>/dev/null
exit 0
CFSTARTEOF
        chmod +x /usr/local/bin/cloudflared-start.sh
        pkill -9 -f "/usr/local/bin/cloudflared" >/dev/null 2>&1
        sleep 1
        /usr/local/bin/cloudflared-start.sh
        sleep 2
        if pgrep -f "/usr/local/bin/cloudflared tunnel" >/dev/null 2>&1; then
            ok "cloudflared 已启动"
        else
            warn "cloudflared 未能启动，查看日志: cat /var/log/cloudflared.log"
        fi
    else
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
fi

# ---------- Alpine 看门狗：每分钟检查一次，进程不在了就自动拉起 ----------
# (Debian/Ubuntu 用的是 systemd 的 Restart=on-failure，已经自带自动重启，不需要这个)
if [ "$INIT_SYS" = openrc ]; then
    info "配置 crond 看门狗（每分钟自愈检查）..."
    apk add --no-cache busybox-openrc >/dev/null 2>&1
    cat > /usr/local/bin/nat-watchdog.sh << 'WDEOF'
#!/bin/sh
[ -x /usr/local/bin/sing-box ] && ! pgrep -f "/usr/local/bin/sing-box run" >/dev/null 2>&1 \
    && rc-service sing-box start >/dev/null 2>&1
[ -x /usr/local/bin/cloudflared-start.sh ] && /usr/local/bin/cloudflared-start.sh >/dev/null 2>&1
exit 0
WDEOF
    chmod +x /usr/local/bin/nat-watchdog.sh
    mkdir -p /etc/crontabs
    ( crontab -l -u root 2>/dev/null | grep -v nat-watchdog.sh; \
      echo "* * * * * /usr/local/bin/nat-watchdog.sh >/dev/null 2>&1" ) | crontab -u root - 2>/dev/null
    rc-update add crond default >/dev/null 2>&1
    rc-service crond start >/dev/null 2>&1 || rc-service crond restart >/dev/null 2>&1
    ok "看门狗已启用：sing-box/cloudflared 掉线会在1分钟内自动拉起"
fi

cat > /usr/local/bin/node << 'PANELEOF'
#!/bin/bash
CONF=/etc/sing-box/node.conf
[ -f "$CONF" ] || { echo "未找到配置: $CONF"; exit 1; }
. "$CONF"
RED='\033[0;31m';GRN='\033[0;32m';YLW='\033[0;33m';CYN='\033[0;36m';BLD='\033[1m';NC='\033[0m'

ask(){ # ask "提示语" 变量名  —— 同样强制从 /dev/tty 读取，防止管道/非交互场景卡死或秒过
    local __prompt="$1" __var="$2"
    if [ -r /dev/tty ]; then
        read -r -p "$__prompt" "$__var" < /dev/tty
    else
        read -r -p "$__prompt" "$__var"
    fi
}

# INIT_SYS / OS_FAMILY 已从 node.conf 载入；做一次兜底探测防止旧配置没有该字段
if [ -z "$INIT_SYS" ]; then
    if command -v rc-service >/dev/null 2>&1; then INIT_SYS="openrc"; else INIT_SYS="systemd"; fi
fi

svc_restart(){
    if [ "$1" = cloudflared ]; then
        pkill -9 -f "/usr/local/bin/cloudflared" >/dev/null 2>&1
        sleep 1
        [ -x /usr/local/bin/cloudflared-start.sh ] && /usr/local/bin/cloudflared-start.sh >/dev/null 2>&1
        return
    fi
    if [ "$INIT_SYS" = openrc ]; then
        # 先 stop 再清理可能残留的 pidfile/状态标记，最后 start，避免
        # 进程管理误判"已经在运行"而拒绝启动的僵尸状态问题
        rc-service "$1" stop >/dev/null 2>&1
        pkill -9 -f "/usr/local/bin/$1" >/dev/null 2>&1
        rm -f "/run/$1.pid" 2>/dev/null
        rc-service "$1" zap >/dev/null 2>&1
        rc-service "$1" start >/dev/null 2>&1
    else
        systemctl restart "$1" >/dev/null 2>&1
    fi
}
svc_is_active(){
    # 用真实进程存在与否做最终判断，比 rc-service/systemctl 自己的状态位更可靠
    # （容器环境里进程管理记录的状态有时会跟实际进程情况对不上）
    case "$1" in
        sing-box)    pgrep -f "/usr/local/bin/sing-box run" >/dev/null 2>&1 && return 0 || return 1;;
        cloudflared) pgrep -f "/usr/local/bin/cloudflared tunnel" >/dev/null 2>&1 && return 0 || return 1;;
    esac
    if [ "$INIT_SYS" = openrc ]; then
        rc-service "$1" status 2>/dev/null | grep -q started
    else
        systemctl is-active --quiet "$1" 2>/dev/null
    fi
}
svc_log_hint(){
    if [ "$INIT_SYS" = openrc ]; then echo "cat /var/log/$1.log"
    else echo "journalctl -u $1 -n 30"
    fi
}
svc_log_tail(){
    if [ "$INIT_SYS" = openrc ]; then tail -n 20 "/var/log/$1.log" 2>/dev/null || echo "  无日志"
    else journalctl -u "$1" --no-pager -n 20 2>/dev/null || echo "  无日志"
    fi
}

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
INIT_SYS=${INIT_SYS}
OS_FAMILY=${OS_FAMILY}
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

_reload(){
    _save; _write_config
    svc_restart sing-box
    [ -n "$CF_TOKEN" ] && [ -f /usr/local/bin/cloudflared ] && svc_restart cloudflared
    echo -e "${GRN}✅ 已重启${NC}"
}

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
    echo -e "${BLD}── 服务状态 (${INIT_SYS}) ────────────────────────────────${NC}"
    for s in sing-box cloudflared; do
        if svc_is_active "$s"; then
            echo -e "  ${s}: ${GRN}● 运行中${NC}"
        else
            echo -e "  ${s}: ${RED}● 未运行${NC} → $(svc_log_hint "$s")"
        fi
    done
    echo ""
    echo -e "${BLD}── 监听端口 ────────────────────────────────────────${NC}"
    if command -v ss >/dev/null 2>&1; then
        ss -tulpn 2>/dev/null|grep sing-box||echo "  未见端口（服务未运行？）"
    else
        netstat -tulpn 2>/dev/null|grep sing-box||echo "  未见端口（服务未运行，或缺少 ss/netstat）"
    fi
    echo ""
    echo -e "${BLD}── sing-box 日志（最近20行）────────────────────────${NC}"
    svc_log_tail sing-box
}

_uninstall(){
    echo -e "${RED}⚠ 将彻底删除 sing-box/cloudflared 及所有配置！${NC}"
    ask "输入 yes 确认: " C; [ "$C" = "yes" ]||{ echo 已取消; return; }
    if [ "$INIT_SYS" = openrc ]; then
        rc-service sing-box stop 2>/dev/null||true
        rc-update del sing-box default 2>/dev/null||true
        rm -f /etc/init.d/sing-box
        pkill -9 -f "/usr/local/bin/cloudflared" 2>/dev/null||true
        ( crontab -l -u root 2>/dev/null | grep -v nat-watchdog.sh ) | crontab -u root - 2>/dev/null||true
        rm -f /usr/local/bin/nat-watchdog.sh /usr/local/bin/cloudflared-start.sh
    else
        systemctl stop sing-box cloudflared 2>/dev/null||true
        systemctl disable sing-box cloudflared 2>/dev/null||true
        rm -f /etc/systemd/system/sing-box.service /etc/systemd/system/cloudflared.service
        systemctl daemon-reload
    fi
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
    ask "  ❯ " OPT
    case "$OPT" in
        1) _show_nodes; ask "回车返回..." _;;
        2) _show_status; ask "回车返回..." _;;
        3) ask "Argo域名(当前:${ARGO_DOMAIN:-未设置}): " v; [ -n "$v" ]&&ARGO_DOMAIN="$v"; _save
           echo -e "${GRN}已保存。去CF确认Public Hostname→Service:http://127.0.0.1:${VMESS_PORT}${NC}"
           ask "回车继续..." _;;
        4) ask "CDN域名(当前:${CDN_DOMAIN:-未设置}): " v; [ -n "$v" ]&&CDN_DOMAIN="$v"
           ask "WS路径(当前:${CDN_PATH},回车不改): " v; [ -n "$v" ]&&CDN_PATH="/${v#/}"
           ask "端口(当前:${CDN_PORT},回车不改): " v; [ -n "$v" ]&&CDN_PORT="$v"
           _reload; ask "回车继续..." _;;
        5) ask "新UUID(回车随机): " v; UUID=${v:-$(_gen_uuid)}; _reload
           echo -e "新UUID:${BLD}${UUID}${NC}"; ask "回车继续..." _;;
        6) ask "TUIC端口(当前:${TUIC_PORT}): " v; [ -n "$v" ]&&TUIC_PORT="$v"
           ask "Reality端口(当前:${REALITY_PORT}): " v; [ -n "$v" ]&&REALITY_PORT="$v"
           ask "CDN端口(当前:${CDN_PORT}): " v; [ -n "$v" ]&&CDN_PORT="$v"
           ask "VMess内部端口(当前:${VMESS_PORT}): " v; [ -n "$v" ]&&VMESS_PORT="$v"
           _reload; ask "回车继续..." _;;
        7) ask "公网IP(当前:${IP4}): " v; [ -n "$v" ]&&IP4="$v"; _save
           echo -e "${GRN}已保存${NC}"; ask "回车继续..." _;;
        8) svc_restart sing-box && echo -e "${GRN}sing-box已重启${NC}"||echo -e "${RED}重启失败${NC}"
           [ -f /usr/local/bin/cloudflared ] && svc_restart cloudflared && echo -e "${GRN}cloudflared已重启${NC}"
           ask "回车继续..." _;;
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

pgrep -f "/usr/local/bin/sing-box run" >/dev/null 2>&1 && SB_ST="active" || SB_ST="inactive"
pgrep -f "/usr/local/bin/cloudflared tunnel" >/dev/null 2>&1 && CF_ST="active" || CF_ST="inactive"
if [ "$INIT_SYS" = openrc ]; then
    SB_LOG_HINT="cat /var/log/sing-box.log"
else
    SB_LOG_HINT="journalctl -u sing-box -n 30"
fi

echo -e "${BLD}${GRN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║             🎉  安装完成！                      ║"
echo "╚══════════════════════════════════════════════════╝${NC}"
echo -e "  sing-box   :$([ "$SB_ST" = "active" ]&&echo " ${GRN}● 运行中${NC}"||echo " ${RED}● 未运行 → ${SB_LOG_HINT}${NC}")"
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
