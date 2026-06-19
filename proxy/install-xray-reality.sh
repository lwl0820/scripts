#!/usr/bin/env bash
set -Eeuo pipefail

# Xray Reality 离线安装脚本
# 适用环境：Debian/Ubuntu + systemd
# 用法：
#   sudo bash proxy/install-xray-reality.sh
#   sudo PORT=443 SNI=www.microsoft.com DEST=www.microsoft.com:443 bash proxy/install-xray-reality.sh
#
# 安装完成后会输出可直接导入代理工具的 VLESS URL。

PORT="${PORT:-443}"
SNI="${SNI:-www.microsoft.com}"
DEST="${DEST:-www.microsoft.com:443}"
FLOW="${FLOW:-xtls-rprx-vision}"
XRAY_VERSION="${XRAY_VERSION:-latest}"
CLIENT_NAME="${CLIENT_NAME:-xray-reality}"
SERVER_HOST="${SERVER_HOST:-}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-/usr/local/etc/xray}"
DAT_DIR="${DAT_DIR:-/usr/local/share/xray}"
SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/xray.service}"

XRAY_BIN="${INSTALL_DIR}/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
TMP_DIR=""
XRAY_ARCH=""
UUID=""
PRIVATE_KEY=""
PUBLIC_KEY=""
SHORT_ID=""
SERVER_IP_OR_HOST=""

log() { printf '[信息] %s\n' "$*"; }
warn() { printf '[警告] %s\n' "$*" >&2; }
die() { printf '[错误] %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [ -n "${TMP_DIR}" ] && [ -d "${TMP_DIR}" ]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "请使用 root 运行：sudo bash $0"
}

install_dependencies() {
  command_exists systemctl || die "未找到 systemctl。本脚本仅支持 Debian/Ubuntu + systemd。"
  command_exists apt-get || die "未找到 apt-get。本脚本仅支持 Debian/Ubuntu。"

  local missing=()
  command_exists curl || missing+=("curl")
  command_exists unzip || missing+=("unzip")
  command_exists openssl || missing+=("openssl")
  command_exists update-ca-certificates || missing+=("ca-certificates")

  if [ "${#missing[@]}" -gt 0 ]; then
    log "安装依赖：${missing[*]}"
    apt-get update
    apt-get install -y curl unzip openssl ca-certificates
  fi
}

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64)
      XRAY_ARCH="64"
      ;;
    aarch64|arm64)
      XRAY_ARCH="arm64-v8a"
      ;;
    armv7l|armv7)
      XRAY_ARCH="arm32-v7a"
      ;;
    *)
      die "不支持的 CPU 架构：${arch}"
      ;;
  esac
  log "检测到架构：${arch}，使用 Xray-linux-${XRAY_ARCH}.zip"
}

download_xray() {
  local url
  TMP_DIR="$(mktemp -d)"

  if [ "${XRAY_VERSION}" = "latest" ]; then
    url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip"
  else
    url="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${XRAY_ARCH}.zip"
  fi

  log "下载 Xray：${url}"
  curl -fL --retry 3 --connect-timeout 15 -o "${TMP_DIR}/xray.zip" "${url}"

  log "解压 Xray release 文件"
  unzip -q "${TMP_DIR}/xray.zip" -d "${TMP_DIR}/xray"
  [ -f "${TMP_DIR}/xray/xray" ] || die "release 包中未找到 xray 二进制文件。"
  [ -f "${TMP_DIR}/xray/geoip.dat" ] || die "release 包中未找到 geoip.dat。"
  [ -f "${TMP_DIR}/xray/geosite.dat" ] || die "release 包中未找到 geosite.dat。"
}

backup_if_exists() {
  local path="$1"
  if [ -e "${path}" ]; then
    local backup="${path}.bak.$(date +%Y%m%d%H%M%S)"
    log "备份已有文件：${path} -> ${backup}"
    cp -a "${path}" "${backup}"
  fi
}

install_xray_files() {
  log "安装 Xray 二进制和 geo 数据"
  install -d -m 755 "${INSTALL_DIR}" "${CONFIG_DIR}" "${DAT_DIR}"

  backup_if_exists "${XRAY_BIN}"
  backup_if_exists "${DAT_DIR}/geoip.dat"
  backup_if_exists "${DAT_DIR}/geosite.dat"

  install -m 755 "${TMP_DIR}/xray/xray" "${XRAY_BIN}"
  install -m 644 "${TMP_DIR}/xray/geoip.dat" "${DAT_DIR}/geoip.dat"
  install -m 644 "${TMP_DIR}/xray/geosite.dat" "${DAT_DIR}/geosite.dat"
}

generate_uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    UUID="$(cat /proc/sys/kernel/random/uuid)"
  else
    UUID="$("${XRAY_BIN}" uuid)"
  fi
}

generate_short_id() {
  SHORT_ID="$(openssl rand -hex 8)"
}

validate_inputs() {
  case "${PORT}" in
    ''|*[!0-9]*)
      die "PORT 必须是数字，例如：PORT=443"
      ;;
  esac

  if [ "${PORT}" -lt 1 ] || [ "${PORT}" -gt 65535 ]; then
    die "PORT 必须在 1 到 65535 之间。"
  fi
}

generate_reality_keys() {
  local key_output
  key_output="$("${XRAY_BIN}" x25519)"
  PRIVATE_KEY="$(printf '%s\n' "${key_output}" | awk -F': ' '/Private key/ {print $2}')"
  PUBLIC_KEY="$(printf '%s\n' "${key_output}" | awk -F': ' '/Public key/ {print $2}')"

  [ -n "${PRIVATE_KEY}" ] || die "生成 Reality 私钥失败。"
  [ -n "${PUBLIC_KEY}" ] || die "生成 Reality 公钥失败。"
}

json_escape() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  input="${input//$'\n'/\\n}"
  input="${input//$'\r'/\\r}"
  input="${input//$'\t'/\\t}"
  printf '%s' "${input}"
}

url_encode() {
  local input="$1"
  local encoded=""
  local i char hex
  local LC_ALL=C

  for ((i = 0; i < ${#input}; i++)); do
    char="${input:i:1}"
    case "${char}" in
      [a-zA-Z0-9.~_-])
        encoded+="${char}"
        ;;
      *)
        printf -v hex '%%%02X' "'${char}"
        encoded+="${hex}"
        ;;
    esac
  done

  printf '%s' "${encoded}"
}

detect_public_host() {
  if [ -n "${SERVER_HOST}" ]; then
    SERVER_IP_OR_HOST="${SERVER_HOST}"
    return
  fi

  SERVER_IP_OR_HOST="$(curl -fsS --max-time 8 https://api.ipify.org || true)"
  if [ -z "${SERVER_IP_OR_HOST}" ]; then
    SERVER_IP_OR_HOST="YOUR_SERVER_IP"
    warn "无法自动获取公网 IP，分享 URL 中的 YOUR_SERVER_IP 需要手动替换。"
  fi
}

write_config() {
  local escaped_uuid escaped_flow escaped_dest escaped_sni escaped_private_key escaped_short_id
  escaped_uuid="$(json_escape "${UUID}")"
  escaped_flow="$(json_escape "${FLOW}")"
  escaped_dest="$(json_escape "${DEST}")"
  escaped_sni="$(json_escape "${SNI}")"
  escaped_private_key="$(json_escape "${PRIVATE_KEY}")"
  escaped_short_id="$(json_escape "${SHORT_ID}")"

  log "写入 Xray 配置：${CONFIG_FILE}"
  install -d -m 755 "${CONFIG_DIR}"
  backup_if_exists "${CONFIG_FILE}"

  cat > "${CONFIG_FILE}" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-reality-in",
      "listen": "0.0.0.0",
      "port": ${PORT},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${escaped_uuid}",
            "flow": "${escaped_flow}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${escaped_dest}",
          "xver": 0,
          "serverNames": [
            "${escaped_sni}"
          ],
          "privateKey": "${escaped_private_key}",
          "shortIds": [
            "${escaped_short_id}"
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
EOF
  chmod 644 "${CONFIG_FILE}"
}

write_service() {
  log "写入 systemd 服务：${SERVICE_FILE}"
  backup_if_exists "${SERVICE_FILE}"

  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${XRAY_BIN} run -config ${CONFIG_FILE}
Restart=on-failure
RestartPreventExitStatus=23
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

validate_config() {
  log "验证 Xray 配置"
  "${XRAY_BIN}" run -test -config "${CONFIG_FILE}"
}

restart_service() {
  log "启动 xray.service"
  systemctl daemon-reload
  systemctl enable xray.service
  systemctl restart xray.service
  systemctl --no-pager --full status xray.service >/dev/null || die "xray.service 启动失败，请运行：journalctl -u xray.service -e"
}

print_result() {
  local encoded_name encoded_flow encoded_sni encoded_public_key encoded_short_id url
  encoded_name="$(url_encode "${CLIENT_NAME}")"
  encoded_flow="$(url_encode "${FLOW}")"
  encoded_sni="$(url_encode "${SNI}")"
  encoded_public_key="$(url_encode "${PUBLIC_KEY}")"
  encoded_short_id="$(url_encode "${SHORT_ID}")"
  url="vless://${UUID}@${SERVER_IP_OR_HOST}:${PORT}?type=tcp&security=reality&encryption=none&flow=${encoded_flow}&sni=${encoded_sni}&fp=chrome&pbk=${encoded_public_key}&sid=${encoded_short_id}&spx=%2F#${encoded_name}"

  cat <<EOF

============================================================
Xray Reality 安装完成
============================================================
请确认云厂商安全组和本机防火墙已放行 TCP ${PORT}。

可直接导入代理工具的 VLESS URL：
${url}

手动填写参数：
地址: ${SERVER_IP_OR_HOST}
端口: ${PORT}
UUID: ${UUID}
协议: VLESS
传输: TCP
security: reality
flow: ${FLOW}
SNI: ${SNI}
Reality public key: ${PUBLIC_KEY}
Reality shortId: ${SHORT_ID}
fingerprint: chrome
spiderX: /

敏感信息提示：
Reality private key: ${PRIVATE_KEY}
请妥善保存 UUID、shortId 和私钥；不要公开分享这些服务凭据。
============================================================
EOF
}

main() {
  need_root
  validate_inputs
  install_dependencies
  detect_arch
  download_xray
  install_xray_files
  generate_uuid
  generate_short_id
  generate_reality_keys
  write_config
  write_service
  validate_config
  restart_service
  detect_public_host
  print_result
}

main "$@"
