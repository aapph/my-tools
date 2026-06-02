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

# 1. 自动从官方 GitHub 获取最新稳定版本号
echo -e "\033[0;33m[1/4] 正在检测官方最新稳定版本号...\033[0m"
LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | jq -r .tag_name)

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" == "null" ]; then
    echo -e "\033[0;31m❌ 无法获取官方最新版本，将默认尝试下载 v1.11.0 稳定版\033[0m"
    LATEST_VERSION="v1.11.0"
fi

VERSION_NUM=$(echo "$LATEST_VERSION" | sed 's/^v//')

echo -e "💡 官方最新版本为: \033[0;32m${LATEST_VERSION}\033[0m"
read -p "👉 直接回车升级到最新版，或输入你想指定的版本号 (例如 1.10.3): " USER_VERSION

if [ -n "$USER_VERSION" ]; then
    VERSION_NUM=$(echo "$USER_VERSION" | sed 's/^v//')
    LATEST_VERSION="v${VERSION_NUM}"
fi

# 2. 创建影子热备份，买好不掉线保险
echo -e "\033[0;33m[2/4] 正在为当前运行中的稳定核心创建影子备份...\033[0m"
cp -f /usr/local/bin/sing-box /usr/local/bin/sing-box.bak

# 3. 拉取对应的官方预编译新核心
echo -e "\033[0;33m[3/4] 正在下载 sing-box-${LATEST_VERSION}-linux-amd64...\033[0m"
wget -q "https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${VERSION_NUM}-linux-amd64.tar.gz" -O sing-box-update.tar.gz

if [ $? -ne 0 ]; then
    wget -q "https://ghproxy.com/https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${VERSION_NUM}-linux-amd64.tar.gz" -O sing-box-update.tar.gz
fi

if [ ! -f "sing-box-update.tar.gz" ] || [ ! -s "sing-box-update.tar.gz" ]; then
    echo -e "\033[0;31m❌ 下载失败！请检查网络或确认该版本号是否存在。\033[0m"
    rm -f sing-box-update.tar.gz
    exit 1
fi

# 4. 安全替换执行文件
echo -e "\033[0;33m[4/4] 正在替换核心执行文件并保持端口矩阵不变...\033[0m"
systemctl stop sing-box

tar -zxf sing-box-update.tar.gz
mv -f sing-box-${VERSION_NUM}-linux-amd64/sing-box /usr/local/bin/
chmod +x /usr/local/bin/sing-box

rm -rf sing-box-update.tar.gz sing-box-${VERSION_NUM}-linux-amd64

# 5. 语法预检与智能熔断回退（带自定义端口和环境对齐）
echo -e "\033[0;33m🔍 正在用你当前运行的自定义端口矩阵 [VLESS:${PORT_VLESS} | Hy2:${PORT_HY2}] 进行新版兼容性预检...\033[0m"
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

if [ $? -eq 0 ]; then
    echo -e "\033[0;32m✅ 配置文件在新核心下完美兼容！正在拉起新服务...\033[0m"
    systemctl restart sing-box
    rm -f /usr/local/bin/sing-box.bak  # 彻底无损升级成功，销毁影子备份
    
    echo -e "👑 \033[0;32m核心升级成功！当前网络矩阵版本为：\033[0m"
    /usr/local/bin/sing-box version | head -n 1
    echo -e "--------------------------------------------------"
    echo -e "\033[0;32m🔄 正在为您刷新并同步展示最新订阅面板信息...\033[0m"
    sleep 1
    # 核心大招：直接调起三合一里的常驻面板，让它以最新的内核和现存端口重新渲染！
    show-nodes
else
    echo -e "\033[0;31m🚨 警告：新核心拒绝解析当前配置语法！正在启动全自动秒级熔断机制...\033[0m"
    mv -f /usr/local/bin/sing-box.bak /usr/local/bin/sing-box
    chmod +x /usr/local/bin/sing-box
    systemctl restart sing-box
    echo -e "\033[0;32m🛡️  熔断回滚成功！已为你自动恢复升级前的稳健核心与全部自定义端口配置，节点未中断！\033[0m"
fi
echo -e "=================================================="
EOF
chmod +x update_singbox.sh
./update_singbox.sh
