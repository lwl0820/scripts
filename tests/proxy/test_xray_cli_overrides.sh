#!/usr/bin/env bash
set -Eeuo pipefail

# 回归测试：验证脚本支持把配置写成命令行 KEY=value 参数。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/proxy/install-xray-reality.sh"

source <(sed '$d' "${SCRIPT_PATH}")

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "${expected}" != "${actual}" ]; then
    printf 'FAIL: %s\n期望: %s\n实际: %s\n' "${message}" "${expected}" "${actual}" >&2
    exit 1
  fi
}

apply_cli_overrides \
  PORT=443 \
  SNI=example.com \
  CLIENT_NAME=my-node \
  INSTALL_DIR=/opt/xray/bin \
  CONFIG_DIR=/opt/xray/config
refresh_derived_paths

assert_equal "443" "${PORT}" "PORT 参数覆盖"
assert_equal "example.com" "${SNI}" "SNI 参数覆盖"
assert_equal "my-node" "${CLIENT_NAME}" "CLIENT_NAME 参数覆盖"
assert_equal "/opt/xray/bin/xray" "${XRAY_BIN}" "INSTALL_DIR 派生路径"
assert_equal "/opt/xray/config/config.json" "${CONFIG_FILE}" "CONFIG_DIR 派生路径"

printf 'PASS: KEY=value 命令行参数覆盖测试通过\n'
