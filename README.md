### 👑科学上网终极核心矩阵
本项目经过AI号称的骨灰级调优，包含**完美双栈 + 五协议矩阵 + 临时/固定双隧道共存**的完全体一键脚本。五协议分别为VMess-临时/固定隧道、VLESS-reality、Trojan、Hysteria2、Tuic。一键脚本经过AI多轮辅助调试聚合，专为低配 VPS（如GCP/AWS等免费小鸡）打造，轻量、稳定、极度隐蔽。

---
### 🚀 一键五协议安装脚本
直接复制命令并在VPS 终端（Root 用户）中运行即可：
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh)
```
---
### 🛠️ 日常管理命令
​安装完成后，在终端里使用以下命令进行日常维护：

重新查看五个节点信息，VPS终端输入：
```
show-nodes
```
修改节点端口或修改固定隧道域名，VPS终端输入：
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
singbox默认内核版本为AI推荐的稳定黄金版v1.9.3，足以满足日常需求。升级内核不保证节点兼容可用，建议使用默认版本即可。如需升级，自行评估，自行测试。
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/update_singbox.sh)
```
---
### ⚠️ 免责声明
1、此脚本仅供学习了解, 请于下载后24小时内删除, 不得用于任何盈利目的及商业用途。

2、使用此脚本，必须遵守脚本部署的服务器归属地区以及所在国家的法律法规, 脚本作者不对使用者任何不当行为负责。

3、本项目不对因使用脚本代码引起的任何直接或间接损害负责。

