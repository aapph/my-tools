### 👑科学上网终极核心矩阵
本项目经过AI号称骨灰级调优，包含**完美双栈 + 五协议矩阵 + 临时/固定双隧道共存**的完全体一键脚本。五协议分别为VMess-临时/固定隧道、VLESS-reality、Trojan、Hysteria2、Tuic。专为低配 VPS（如 AWS 免费小鸡）打造，轻量、稳定、极度隐蔽。

---
### 🚀 一键五协议安装脚本
直接复制命令并在VPS 终端（Root 用户）中运行即可：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh)

```
---
### 🛠️ 核心日常管理命令
​安装完成后，在终端里使用以下命令进行日常维护：

想要**再次查看**或**复制**五个节点链接，直接登录 VPS 终端敲入：
```
show-nodes

```
修改节点端口或修改固定隧道域名，VPS终端敲入：
```
port

```
​查看singbox底层运行状态：
```
systemctl status sing-box

```
​零信任永久固定隧道状态：
```
systemctl status cloudflared-zt

```
​临时测试隧道状态：
```
systemctl status cloudflared

```
​一键重启整个网络矩阵：
```
systemctl restart sing-box cloudflared cloudflared-zt

```
---
### 🧹 一键五协议卸载脚本
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/clean.sh)

```
---
### 🚀 一键升级singbox内核脚本
singbox默认内核版本v1.9.3，足以满足本人需求。升级内核不保证可用，因没测试过。如需升级，自行测试。

```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/update_singbox.sh)

