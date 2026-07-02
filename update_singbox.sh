cat << 'EOF' > update_singbox.sh
#!/bin/bash
clear
echo -e "\033[0;32m====== 🚀 开始无损一键升级 sing-box 核心（全自定义矩阵兼容版） ======\033[0m"

# 0. 核心前置：检查并加载本地固化的自定义元数据
if [ ! -f /etc/sing-box/config.json ] || [ ! -f /etc/sing-box/meta_env.sh ]; then
    echo -e "\033[0;31m❌ 错误：未检测到完全体节点的安装环境，请先运行大安装脚本！\033[0m"
    exit 1
fi
source /etc/sing-box/meta_env.sh

# 依赖检查：jq、curl、wget 缺一不可
for DEP in jq curl wget; do
    if ! command -v "$DEP" >/dev/null 2>&1; then
        echo -e "\033[0;33m⚙️  缺少依赖 ${DEP}，正在自动安装...\033[0m"
        apt-get install -y "$DEP" 2>/dev/null || { echo -e "\033[0;31m❌ 安装 ${DEP} 失败，请手动安装后重试！\033[0m"; exit 1; }
    fi
done

# 当前版本展示
CURRENT_VERSION=$(/usr/local/bin/sing-box version 2>/dev/null | head -n1 | awk '{print $NF}')
echo -e "当前运行版本: \033[0;33m${CURRENT_VERSION:-未知}\033[0m"

# 1. 自动从官方 GitHub 获取最新稳定版本号
echo -e "\033[0;33m[1/5] 正在检测官方最新稳定版本号...\033[0m"
LATEST_VERSION=$(curl -sf --max-time 10 https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r '.tag_name // empty')

if [ -z "$LATEST_VERSION" ]; then
    echo -e "\033[0;31m❌ 无法获取官方最新版本（网络超时或 API 限速），将默认尝试下载 v1.11.0 稳定版\033[0m"
    LATEST_VERSION="v1.11.0"
fi

VERSION_NUM=$(echo "$LATEST_VERSION" | sed 's/^v//')
echo -e "💡 官方最新版本为: \033[0;32m${LATEST_VERSION}\033[0m"

if [ "$CURRENT_VERSION" = "$VERSION_NUM" ]; then
    echo -e "\033[0;36m✅ 当前已是最新版本，无需升级。\033[0m"
    read -p "👉 仍然强制重装当前版本？(y/N): " FORCE
    [ "${FORCE,,}" != "y" ] && exit 0
fi

read -p "👉 直接回车升级到最新版，或输入你想指定的版本号 (例如 1.10.3): " USER_VERSION
if [ -n "$USER_VERSION" ]; then
    VERSION_NUM=$(echo "$USER_VERSION" | sed 's/^v//')
    LATEST_VERSION="v${VERSION_NUM}"
fi

# 2. 创建影子热备份
echo -e "\033[0;33m[2/5] 正在为当前运行中的稳定核心创建影子备份...\033[0m"
if [ ! -f /usr/local/bin/sing-box ]; then
    echo -e "\033[0;31m❌ 未找到 /usr/local/bin/sing-box，环境异常，中止！\033[0m"
    exit 1
fi
cp -f /usr/local/bin/sing-box /usr/local/bin/sing-box.bak

# 下载失败时的统一清理+回滚函数
rollback() {
    echo -e "\033[0;31m🚨 $1\033[0m"
    echo -e "\033[0;33m🔄 正在启动熔断回滚...\033[0m"
    rm -f sing-box-update.tar.gz
    rm -rf "sing-box-${VERSION_NUM}-linux-amd64"
    if [ -f /usr/local/bin/sing-box.bak ]; then
        mv -f /usr/local/bin/sing-box.bak /usr/local/bin/sing-box
        chmod +x /usr/local/bin/sing-box
        systemctl restart sing-box
        echo -e "\033[0;32m🛡️  熔断回滚成功！已恢复升级前稳定核心，节点未中断！\033[0m"
    else
        echo -e "\033[0;31m⚠️  备份文件丢失，无法自动回滚，请手动重装！\033[0m"
    fi
    exit 1
}

# 3. 拉取新核心
echo -e "\033[0;33m[3/5] 正在下载 sing-box ${LATEST_VERSION} (linux-amd64)...\033[0m"
DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${VERSION_NUM}-linux-amd64.tar.gz"
MIRROR_URL="https://ghproxy.com/${DOWNLOAD_URL}"

wget -q --show-progress "$DOWNLOAD_URL" -O sing-box-update.tar.gz 2>/dev/null \
  || wget -q --show-progress "$MIRROR_URL" -O sing-box-update.tar.gz 2>/dev/null

if [ ! -s sing-box-update.tar.gz ]; then
    rollback "下载失败！请检查网络或确认版本号 ${LATEST_VERSION} 是否存在。"
fi

# 4. 解压并替换
echo -e "\033[0;33m[4/5] 正在替换核心执行文件...\033[0m"
tar -zxf sing-box-update.tar.gz || rollback "解压失败，归档文件可能已损坏。"

NEW_BIN="sing-box-${VERSION_NUM}-linux-amd64/sing-box"
if [ ! -f "$NEW_BIN" ]; then
    rollback "解压后未找到可执行文件 ${NEW_BIN}，目录结构与预期不符。"
fi

systemctl stop sing-box
mv -f "$NEW_BIN" /usr/local/bin/sing-box
chmod +x /usr/local/bin/sing-box
rm -rf sing-box-update.tar.gz "sing-box-${VERSION_NUM}-linux-amd64"

# 5. 语法预检与智能熔断回退
echo -e "\033[0;33m[5/5] 用当前配置进行新版兼容性预检 [VLESS:${PORT_VLESS} | Hy2:${PORT_HY2} | TUIC:${PORT_TUIC}]...\033[0m"
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

if [ $? -eq 0 ]; then
    systemctl restart sing-box
    rm -f /usr/local/bin/sing-box.bak
    echo -e ""
    echo -e "\033[0;32m✅ 升级成功！当前核心版本：\033[0m"
    /usr/local/bin/sing-box version | head -n 1
    echo -e "--------------------------------------------------"
    sleep 1
    show-nodes
else
    rollback "新核心拒绝解析当前配置语法！"
fi
echo -e "=================================================="
EOF
chmod +x update_singbox.sh
./update_singbox.sh
