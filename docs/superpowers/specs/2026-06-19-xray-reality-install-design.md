# Xray XTLS-Vision Reality 离线安装脚本设计

## 背景

在 `proxy` 目录中新增一个面向 Debian/Ubuntu + systemd 的安装脚本，用来部署 Xray，并启用 `VLESS + TCP + XTLS Vision + Reality`。用户已选择方案 B：脚本直接下载并安装 Xray release 二进制与地理数据文件，不调用官方安装脚本。

## 目标

- 在一台干净的 Debian/Ubuntu VPS 上安装 Xray。
- 自动生成 Reality 所需的 UUID、X25519 密钥对和 shortId。
- 写入可直接运行的 Xray 服务端配置。
- 写入 systemd unit，启用并启动 `xray.service`。
- 在安装完成后输出客户端连接所需的关键参数。
- 在安装完成后生成可直接导入常见代理工具的 VLESS 分享 URL。
- 所有给人看的说明、注释和错误信息至少包含简体中文。

## 非目标

- 不实现多用户管理面板。
- 不自动配置域名 DNS。
- 不自动申请 TLS 证书，Reality 不需要本机证书。
- 不强制改防火墙规则；只在输出中提示需要放行监听端口。
- 不支持非 systemd 发行版。

## 脚本位置

新增：

- `proxy/install-xray-reality.sh`

## 运行方式

默认运行：

```bash
sudo bash proxy/install-xray-reality.sh
```

可用环境变量覆盖默认值：

```bash
sudo PORT=443 SNI=www.microsoft.com DEST=www.microsoft.com:443 bash proxy/install-xray-reality.sh
```

## 关键参数

- `PORT`：监听端口，默认 `443`。
- `SNI`：Reality serverNames 和客户端 SNI，默认 `www.microsoft.com`。
- `DEST`：Reality dest，默认 `www.microsoft.com:443`。
- `FLOW`：VLESS flow，默认 `xtls-rprx-vision`。
- `XRAY_VERSION`：Xray 版本，默认 `latest`，也可指定如 `v25.6.8`。
- `CLIENT_NAME`：分享 URL 中的节点名称，默认 `xray-reality`。
- `INSTALL_DIR`：Xray 二进制目录，默认 `/usr/local/bin`。
- `CONFIG_DIR`：Xray 配置目录，默认 `/usr/local/etc/xray`。
- `DAT_DIR`：geo 数据目录，默认 `/usr/local/share/xray`。
- `SERVICE_FILE`：systemd unit 路径，默认 `/etc/systemd/system/xray.service`。

## 安装流程

1. 检查必须以 root 运行。
2. 检查系统依赖：`curl`、`unzip`、`systemctl`。缺失时使用 `apt-get` 安装。
3. 检测 CPU 架构并映射到 Xray release 资产名：
   - `x86_64` / `amd64` -> `64`
   - `aarch64` / `arm64` -> `arm64-v8a`
   - `armv7l` -> `arm32-v7a`
4. 下载 Xray release zip。
   - `XRAY_VERSION=latest` 时使用 GitHub latest download URL。
   - 指定版本时使用对应 tag 的 download URL。
5. 解压 `xray`、`geoip.dat`、`geosite.dat`。
6. 安装到目标目录并设置权限。
7. 使用 `xray x25519` 生成 Reality 密钥对。
8. 使用 `/proc/sys/kernel/random/uuid` 或 `xray uuid` 生成 UUID。
9. 使用 `openssl rand -hex 8` 或备用方式生成 shortId。
10. 写入 `/usr/local/etc/xray/config.json`。
11. 写入 `/etc/systemd/system/xray.service`。
12. 执行 `systemctl daemon-reload`、`enable`、`restart`。
13. 使用 `systemctl --no-pager --full status xray` 或 `xray run -test -config` 验证。
14. 输出服务端参数和可直接导入代理工具的 VLESS 分享 URL。

## 配置结构

服务端入站配置：

- protocol: `vless`
- network: `tcp`
- security: `reality`
- flow: `xtls-rprx-vision`
- decryption: `none`
- clients: 单个自动生成 UUID
- realitySettings:
  - show: `false`
  - dest: `${DEST}`
  - xver: `0`
  - serverNames: `[${SNI}]`
  - privateKey: 自动生成
  - shortIds: 自动生成

出站配置：

- `freedom`
- `blackhole` 用于阻断部分异常流量可后续扩展，本脚本先保持最小可用。

## 分享 URL

脚本安装完成后必须输出一条 VLESS URL，格式如下：

```text
vless://${UUID}@${SERVER_IP_OR_HOST}:${PORT}?type=tcp&security=reality&encryption=none&flow=${FLOW}&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F#${CLIENT_NAME}
```

其中：

- `SERVER_IP_OR_HOST` 默认通过公网 IP 查询接口获取；如果查询失败，提示用户手动替换。
- `pbk` 使用 Reality 公钥，不输出私钥到 URL。
- `sid` 使用自动生成的 shortId。
- `fp` 默认 `chrome`，兼容常见代理客户端。
- `spx` 默认 `/`，URL 编码为 `%2F`。
- `CLIENT_NAME` 需要进行 URL fragment 编码，避免中文或空格导致导入失败。

脚本仍需同时输出分项参数，便于用户在不支持分享链接的客户端中手动填写。

## 错误处理

- 脚本使用 `set -Eeuo pipefail`。
- 下载、解压、配置测试失败时立即退出。
- 临时目录通过 `trap` 清理。
- 安装前如发现已存在配置，复制为带时间戳的 `.bak` 备份。

## 安全说明

- 安装完成后终端会显示私钥、UUID 和 shortId；这些信息等同于服务凭据，应保存到安全位置。
- Reality 的 `SNI` 和 `DEST` 应选择支持 TLS 1.3、访问稳定且不与服务器自身业务冲突的网站。
- 默认端口 `443` 需要云厂商安全组和本机防火墙放行。

## 测试计划

- 本地静态检查：`bash -n proxy/install-xray-reality.sh`。
- 文本检查：确认脚本包含中文使用说明和注释。
- 运行时检查：脚本内执行 `xray run -test -config /usr/local/etc/xray/config.json`。
