### 👑 科学上网终极核心矩阵
本项目经过AI号称的骨灰级调优，包含**完美双栈 + 七协议矩阵 + vmess/vless-临时/固定双隧道共存**的完全体一键脚本。协议分别为VMess/Vless-临时/固定隧道、vmess-ws-tls/vless-ws-tls(使用CF的五个https端口，可套CDN，例2096端口)、VLESS-reality、Trojan、Hysteria2、Tuic。一键脚本经过AI多轮辅助调试聚合，专为低配 VPS（如GCP/AWS等免费小鸡）打造，轻量、稳定、隐蔽。

---
### 🚀 注意事项
使用vmess/vless固定隧道，需提前在cloudflare的zero trust创建好隧道，获取隧道token以及绑定的隧道域名。两隧道协议可以共用一个token，但需在当前隧道下创建绑定两个隧道域名，需在CF Zero Trust后台为该Tunnel添加两条Public Hostname分别指向http://localhost:8080（vmess隧道默认端口）和http://localhost:8880（vless隧道默认端口），隧道端口可以自定义。
执行脚本需要填token和隧道域名两个参数，填完参数回车就是生成vmess/vless临时/固定双隧道共存。两个参数为选填项，不填直接回车就是单独生成vmess/vless临时隧道。

使用vmess-ws-tls或vless-ws-tls协议，需提前在Cloudflare后台对托管域名添加一个A或AAAA记录，指向VPS的IP，并保持开启"橙云"（已代理）状态，这样 Cloudflare才会在你选的那个端口上做边缘转发，从而实现优选IP/优选域名加速套CDN的效果。

---
### 🚀 一键安装脚本
复制命令并在VPS终端(root用户)中运行：

七协议：
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install.sh)
```
五协议：
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install-1.sh)
```
兼容Nat-VPS四协议： 
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/install-nat.sh)
```
---
### 🛠️ 日常管理命令
​常规VPS，在终端里使用以下命令进行日常维护：

查看节点信息，VPS终端输入：
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

兼容Nat-VPS，在终端输入以下命令进行日常维护。输入命令后，可在管理面板查看节点信息/修改节点信息/卸载脚本等：
```
node
```
---
### 🧹 一键卸载脚本
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/clean.sh)
```
---
### 🚀 一键升级singbox内核脚本
singbox默认内核版本为AI推荐的稳定黄金版v1.9.3，足以满足日常需求。升级内核不保证节点兼容可用。如需升级，可自定义选择自己需要的版本。
```bash
bash <(curl -Ls https://raw.githubusercontent.com/aapph/my-tools/refs/heads/main/update_singbox.sh)
```
---
### ⚠️ 免责声明
1、此脚本仅供学习了解，请于下载后24小时内删除，不得用于任何盈利目的及商业用途。

2、使用此脚本，必须遵守脚本部署的服务器归属地区以及所在国家的法律法规，脚本作者不对使用者任何不当行为负责。

3、本项目不对因使用脚本代码引起的任何直接或间接损害负责。

