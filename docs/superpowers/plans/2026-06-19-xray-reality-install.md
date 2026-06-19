# Xray Reality Install Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `proxy` 目录新增一个 Debian/Ubuntu systemd 环境可用的 Xray Reality 离线安装脚本，并在安装完成后输出可直接导入代理工具的 VLESS URL。

**Architecture:** 单文件 Bash 脚本负责依赖检查、下载 release zip、安装二进制和 geo 数据、生成 Reality 凭据、写入 Xray JSON 配置、写入 systemd unit、验证并启动服务。脚本按函数拆分，避免把下载、配置生成和输出逻辑混在同一段代码里。

**Tech Stack:** Bash, curl, unzip, systemd, Xray core.

---

## File Structure

- Create: `proxy/install-xray-reality.sh`
  - 负责完整安装流程。
  - 包含中文使用说明、错误信息和必要注释。
  - 支持环境变量：`PORT`、`SNI`、`DEST`、`FLOW`、`XRAY_VERSION`、`CLIENT_NAME`、`INSTALL_DIR`、`CONFIG_DIR`、`DAT_DIR`、`SERVICE_FILE`。
- Create: `.gitattributes`
  - 强制 `.sh` 文件使用 LF 换行，避免脚本复制到 Linux 后出现 CRLF 执行问题。

## Task 1: Create Installation Script

**Files:**
- Create: `.gitattributes`
- Create: `proxy/install-xray-reality.sh`

- [x] **Step 1: Create script with strict shell settings and defaults**

Add the complete Bash script with:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Defaults:

```bash
PORT="${PORT:-443}"
SNI="${SNI:-www.microsoft.com}"
DEST="${DEST:-www.microsoft.com:443}"
FLOW="${FLOW:-xtls-rprx-vision}"
XRAY_VERSION="${XRAY_VERSION:-latest}"
CLIENT_NAME="${CLIENT_NAME:-xray-reality}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/xray}"
DAT_DIR="${DAT_DIR:-/usr/local/share/xray}"
SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/xray.service}"
```

- [x] **Step 2: Add helper functions**

Implement these functions in `proxy/install-xray-reality.sh`:

```bash
log() { printf '[信息] %s\n' "$*"; }
warn() { printf '[警告] %s\n' "$*" >&2; }
die() { printf '[错误] %s\n' "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "请使用 root 运行：sudo bash $0"; }
```

Also implement:

```bash
command_exists()
install_dependencies()
detect_arch()
download_xray()
install_xray_files()
backup_if_exists()
generate_uuid()
generate_short_id()
generate_reality_keys()
url_encode()
detect_public_host()
write_config()
write_service()
validate_config()
restart_service()
print_result()
main()
```

- [x] **Step 3: Implement release download without official installer**

Use GitHub release zip URLs directly:

```bash
https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip
https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip
```

Expected behavior:

- `latest` downloads from latest URL.
- A pinned version downloads from tag URL.
- Unsupported CPU architecture exits with Chinese error.

- [x] **Step 4: Generate config and service files**

`config.json` must include:

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "UUID_VALUE",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "xver": 0,
          "serverNames": [
            "www.microsoft.com"
          ],
          "privateKey": "PRIVATE_KEY_VALUE",
          "shortIds": [
            "SHORT_ID_VALUE"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
```

`xray.service` must use:

```ini
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
LimitNOFILE=1048576
```

- [x] **Step 5: Generate importable VLESS URL**

`print_result()` must output:

```text
vless://${UUID}@${SERVER_IP_OR_HOST}:${PORT}?type=tcp&security=reality&encryption=none&flow=${FLOW}&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F#${ENCODED_CLIENT_NAME}
```

It must also print manual fields in Chinese:

```text
地址、端口、UUID、flow、security、SNI、Reality public key、shortId
```

- [x] **Step 6: Validate shell syntax**

Run:

```bash
bash -n proxy/install-xray-reality.sh
```

Expected: exit code `0`, no output.

- [x] **Step 7: Verify required Chinese user-facing text**

Run:

```powershell
Select-String -Path proxy\install-xray-reality.sh -Pattern '使用|错误|安装|导入|防火墙'
```

Expected: matches exist in script output.

- [x] **Step 8: Inspect git diff**

Run:

```bash
git diff -- proxy/install-xray-reality.sh docs/superpowers/plans/2026-06-19-xray-reality-install.md
```

Expected: only the new script and this plan are changed.

- [x] **Step 9: Commit implementation**

Run:

```bash
git add proxy/install-xray-reality.sh docs/superpowers/plans/2026-06-19-xray-reality-install.md
git commit -m "feat: add xray reality install script"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: plan covers Debian/Ubuntu + systemd, direct release zip download, credential generation, config writing, service writing, validation, restart, manual parameters, and importable VLESS URL.
- Placeholder scan: no TODO/TBD placeholders remain.
- Type consistency: parameter names match the design document.
