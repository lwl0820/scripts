#!/usr/bin/env bash
set -Eeuo pipefail

# 回归测试：验证生成的 Xray 配置默认监听双栈地址，并允许手动覆盖监听地址。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/proxy/install-xray-reality.sh"

unset LISTEN
source <(sed '$d' "${SCRIPT_PATH}")

TEST_TMP_PARENT="${ROOT_DIR}/.tmp"
TEST_TMP_DIR="${TEST_TMP_PARENT}/xray-listen-test.$$"
mkdir -p "${TEST_TMP_DIR}"

test_cleanup() {
  rm -rf "${TEST_TMP_DIR}"
  rmdir "${TEST_TMP_PARENT}" 2>/dev/null || true
}
trap test_cleanup EXIT

CONFIG_DIR="${TEST_TMP_DIR}/config"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PORT=443
UUID="00000000-0000-0000-0000-000000000000"
FLOW="xtls-rprx-vision"
DEST="www.apple.com:443"
SNI="www.apple.com"
PRIVATE_KEY="private-key"
SHORT_ID="0011223344556677"

assert_config_has_listen() {
  local expected="$1"
  local message="$2"

  if ! grep -Fq "\"listen\": \"${expected}\"" "${CONFIG_FILE}"; then
    printf 'FAIL: %s\n期望 listen: %s\n实际配置:\n' "${message}" "${expected}" >&2
    cat "${CONFIG_FILE}" >&2
    exit 1
  fi
}

write_config >/dev/null 2>/dev/null
assert_config_has_listen "::" "默认监听地址应支持双栈"

LISTEN="0.0.0.0"
write_config >/dev/null 2>/dev/null
assert_config_has_listen "0.0.0.0" "显式 LISTEN 应写入配置"

printf 'PASS: Xray listen 地址配置测试通过\n'
