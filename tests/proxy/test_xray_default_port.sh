#!/usr/bin/env bash
set -Eeuo pipefail

# 回归测试：验证未显式设置 PORT 时，脚本默认使用随机高位端口。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/proxy/install-xray-reality.sh"

# 只加载函数定义和变量初始化，避免执行安装流程。
unset PORT
source <(sed '$d' "${SCRIPT_PATH}")
validate_inputs

assert_in_range() {
  local value="$1"
  local min="$2"
  local max="$3"
  local message="$4"

  if [ "${value}" -lt "${min}" ] || [ "${value}" -gt "${max}" ]; then
    printf 'FAIL: %s\n期望范围: %s-%s\n实际值: %s\n' "${message}" "${min}" "${max}" "${value}" >&2
    exit 1
  fi
}

case "${PORT}" in
  ''|*[!0-9]*)
    printf 'FAIL: 默认 PORT 必须是数字\n实际值: %s\n' "${PORT}" >&2
    exit 1
    ;;
esac

assert_in_range "${PORT}" 49152 65535 "默认 PORT 应落在 IANA 动态/私有端口范围内"

printf 'PASS: 默认 PORT 为随机高位端口（%s）\n' "${PORT}"
