### 👑科学上网终极核心矩阵
本项目包含经过骨灰级调优的**完美双栈 + 五协议矩阵 + 临时/固定双隧道共存**完全体一键脚本。专为低配 VPS（如 AWS 免费小鸡）打造，轻量、稳定、极度隐蔽。

---
### 🚀 一键安装脚本
选择以下任意一行命令，直接复制并在新 VPS 终端（Root 用户）中运行即可：

### 🇨🇳 国内/全网 CDN 加速拉起（强推，1秒秒下）
```bash
bash <(curl -Ls (https://ghproxy.com/https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh))
```
---
### 🌐 国际直连拉起（海外小鸡直连）
```bash
bash <(curl -Ls (https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh))
```
---
### 🛠️ 核心日常管理命令
​安装完成后，在终端里使用以下命令进行日常维护：
​核心五协议状态自检：
```
systemctl status sing-box
```
​零信任永久固定隧道状态：
```
systemctl status cloudflared-zt
```
​临时测试隧道状态监控：
```
systemctl status cloudflared
```
​一键重启整个网络矩阵：
```
systemctl restart sing-box cloudflared cloudflared-zt
```
---
### 🧹 一键卸载脚本
```bash
bash <(curl -Ls (https://ghproxy.com/https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/clean.sh))
```
