# scripts

这个仓库用于存放可复用的运维脚本。目前主要包含 Xray Reality 安装脚本。

## 目录结构

```text
.
├── proxy/
│   └── install-xray-reality.sh
└── docs/
    └── superpowers/
        ├── plans/
        └── specs/
```

## Xray Reality 安装脚本

脚本位置：

```text
proxy/install-xray-reality.sh
```

该脚本用于在 Debian/Ubuntu + systemd 服务器上安装 Xray，并配置：

- 协议：VLESS
- 传输：TCP
- 安全层：Reality
- flow：XTLS Vision，即 `xtls-rprx-vision`
- 服务：`xray.service`

安装完成后，脚本会输出可直接导入常见代理工具的 `vless://` URL，并同时输出手动填写所需参数。双栈或多 IP 服务器会输出多条导入 URL。

## 运行环境

推荐环境：

- Debian 或 Ubuntu
- systemd
- root 权限
- 可访问 GitHub release 下载地址

脚本会自动检查并安装这些基础依赖：

- `curl`
- `unzip`
- `openssl`
- `ca-certificates`

## 快速使用

一键执行公开仓库脚本：

```bash
sudo bash <(curl -sL https://raw.githubusercontent.com/lwl0820/scripts/main/proxy/install-xray-reality.sh)
```

在服务器上克隆仓库后运行：

```bash
sudo bash proxy/install-xray-reality.sh
```

默认监听端口会在 `49152-65535` 范围内随机生成。运行前请确认云厂商安全组和服务器防火墙已放行脚本最终输出的 TCP 端口。

## 常用参数

可以通过 `KEY=value` 参数覆盖默认值。推荐把参数放在脚本路径后面，这种写法不依赖 `sudo` 是否保留环境变量：

```bash
sudo bash proxy/install-xray-reality.sh \
  PORT=443 \
  LISTEN="::" \
  SNI=www.apple.com \
  DEST=www.apple.com:443 \
  CLIENT_NAME=my-node
```

一键执行远程脚本时也可以使用同样的参数写法：

```bash
sudo bash <(curl -sL https://raw.githubusercontent.com/lwl0820/scripts/main/proxy/install-xray-reality.sh) PORT=443
```

可配置参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | 随机 `49152-65535` | Xray 监听端口；未设置时自动使用高位随机端口 |
| `LISTEN` | `::` | Xray 入站监听地址；默认用于双栈监听。仅需要 IPv4 时可设为 `0.0.0.0` |
| `SNI` | `www.apple.com` | Reality serverNames 和客户端 SNI |
| `DEST` | `www.apple.com:443` | Reality 回落目标 |
| `FLOW` | `xtls-rprx-vision` | VLESS flow |
| `XRAY_VERSION` | `latest` | Xray 版本；也可指定 tag，例如 `v25.6.8` |
| `CLIENT_NAME` | `xray-reality` | 导入 URL 的节点名称 |
| `SERVER_HOSTS` | 自动检测公网 IPv4/IPv6 | 分享 URL 中使用的服务器地址列表，支持逗号分隔多个 IPv4、IPv6 或域名 |
| `SERVER_HOST` | 空 | 兼容旧参数；未设置 `SERVER_HOSTS` 时作为单个服务器地址使用 |
| `INSTALL_DIR` | `/usr/local/bin` | Xray 二进制安装目录 |
| `CONFIG_DIR` | `/usr/local/etc/xray` | Xray 配置目录 |
| `DAT_DIR` | `/usr/local/share/xray` | `geoip.dat` 和 `geosite.dat` 目录 |
| `SERVICE_FILE` | `/etc/systemd/system/xray.service` | systemd 服务文件路径 |

指定固定版本示例：

```bash
sudo XRAY_VERSION=v25.6.8 bash proxy/install-xray-reality.sh
```

自动公网 IP 检测失败时，手动指定服务器地址：

```bash
sudo SERVER_HOSTS=203.0.113.10 bash proxy/install-xray-reality.sh
```

双栈或多 IP 服务器可以一次指定多个地址：

```bash
sudo SERVER_HOSTS="203.0.113.10,[2001:db8::10],proxy.example.com" bash proxy/install-xray-reality.sh
```

IPv6 地址可以写成裸地址或带方括号。脚本生成 URL 时会自动把 IPv6 host 格式化为 `[2001:db8::10]`。

## 安装后输出

安装完成后会输出：

- 可直接导入代理工具的 VLESS URL，可能有多条
- 地址列表
- 端口
- UUID
- Reality public key
- Reality shortId
- SNI
- flow
- fingerprint
- spiderX
- Reality private key

VLESS URL 格式类似：

```text
vless://UUID@SERVER:443?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&sni=www.apple.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&spx=%2F#xray-reality
```

IPv6 地址会出现在方括号中：

```text
vless://UUID@[2001:db8::10]:443?type=tcp&security=reality&encryption=none&flow=xtls-rprx-vision&sni=www.apple.com&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&spx=%2F#xray-reality
```

其中 `pbk` 是 Reality 公钥，`sid` 是 shortId。私钥不会写入导入 URL，但会在安装结果中显示，用于服务端配置备份。

## 重要安全提示

- 安装结果中的 UUID、shortId 和 Reality private key 都属于服务凭据，请妥善保存，不要公开分享。
- Reality 的 `SNI` 和 `DEST` 应选择支持 TLS 1.3、访问稳定且不与服务器自身业务冲突的网站。
- 默认会生成一个高位随机端口，需要在云厂商安全组和本机防火墙中放行该端口。
- 如果导入的是 IPv6 节点，请确认服务器有可用公网 IPv6、云安全组和本机防火墙已放行 IPv6 入站，并且 `LISTEN` 没有被改成只监听 IPv4 的 `0.0.0.0`。
- 重复运行脚本会重新生成 UUID、Reality 密钥和 shortId，并覆盖服务端配置；旧客户端节点会失效，需要导入最后一次安装输出的新 URL。
- 脚本会在覆盖已有 Xray 文件或配置前创建带时间戳的 `.bak` 备份。

## 常用排障命令

查看服务状态：

```bash
sudo systemctl status xray --no-pager --full
```

查看服务日志：

```bash
sudo journalctl -u xray.service -e
```

测试配置文件：

```bash
sudo /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
```

重启服务：

```bash
sudo systemctl restart xray.service
```
