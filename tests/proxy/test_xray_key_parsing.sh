#!/usr/bin/env bash
set -Eeuo pipefail

# 回归测试：验证脚本能兼容不同 Xray 版本的 x25519 输出格式。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/proxy/install-xray-reality.sh"

# 只加载函数定义，避免执行安装流程。
source <(sed '$d' "${SCRIPT_PATH}")

TEST_TMP_PARENT="${ROOT_DIR}/.tmp"
TEST_TMP_DIR="${TEST_TMP_PARENT}/xray-key-test.$$"
mkdir -p "${TEST_TMP_DIR}"

test_cleanup() {
  rm -rf "${TEST_TMP_DIR}"
  rmdir "${TEST_TMP_PARENT}" 2>/dev/null || true
}
trap test_cleanup EXIT

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "${expected}" != "${actual}" ]; then
    printf 'FAIL: %s\n期望: %s\n实际: %s\n' "${message}" "${expected}" "${actual}" >&2
    exit 1
  fi
}

run_case() {
  local name="$1"
  local fake_body="$2"
  local fake_xray="${TEST_TMP_DIR}/xray-${name}"

  cat > "${fake_xray}" <<EOF
#!/usr/bin/env bash
${fake_body}
EOF
  chmod +x "${fake_xray}"

  XRAY_BIN="${fake_xray}"
  PRIVATE_KEY=""
  PUBLIC_KEY=""
  generate_reality_keys

  assert_equal "private-${name}" "${PRIVATE_KEY}" "${name} 私钥解析"
  assert_equal "public-${name}" "${PUBLIC_KEY}" "${name} 公钥解析"
}

run_case "stderr" 'printf "Private key: private-stderr\nPublic key: public-stderr\n" >&2'
run_case "compact" 'printf "PrivateKey: private-compact\nPublicKey: public-compact\n"'
run_case "password-label" 'printf "PrivateKey: private-password-label\nPassword (PublicKey): public-password-label\nHash32: ignored\n"'

printf 'PASS: x25519 密钥解析兼容性测试通过\n'
