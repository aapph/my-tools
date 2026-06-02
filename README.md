### 👑科学上网终极核心矩阵
本项目经过AI号称骨灰级调优，包含**完美双栈 + 五协议矩阵 + 临时/固定双隧道共存**的完全体一键脚本。五协议分别为VMess-临时/固定隧道、VLESS-reality、Trojan、Hysteria2、Tuic。专为低配 VPS（如 AWS 免费小鸡）打造，轻量、稳定、极度隐蔽。AI聚合脚本，使用过程遇到问题自行AI搜索解决。

---
### 🚀 一键五协议安装脚本
直接复制命令并在VPS 终端（Root 用户）中运行即可：
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh)
```
---
### 🛠️ 日常管理命令
​安装完成后，在终端里使用以下命令进行日常维护：

重新查看五个节点信息，直接登录VPS终端敲入：
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
singbox默认内核版本为AI推荐的稳定黄金版v1.9.3，足以满足日常需求。因未测试内核升级，升级内核不保证可用，建议使用默认版本即可。如需升级，自行评估风险，自行测试，概不负责。
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/update_singbox.sh)
```
---
### ⚠️ 免责声明
1、此脚本仅供学习了解, 请于下载后24小时内删除, 不得用于任何盈利目的及商业用途。

2、使用此脚本必须遵守部署服务器所在地、所在国家的法律法规, 脚本作者不对使用者任何不当行为负责。

3、本项目不对因使用代码引起的任何直接或间接损害负责。

