#!/bin/bash
# 测试通知消息生成

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 创建临时工作目录
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "=== 测试通知消息生成 ==="
echo "项目根目录：${PROJECT_ROOT}"
echo "临时目录：${TMPDIR}"
echo ""

# 创建模拟 .config 文件
cat > "${TMPDIR}/.config" << 'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-cs-02=y
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-frpc=y
CONFIG_PACKAGE_luci-app-frps=m
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_luci-app-vlmcsd=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-theme-noobwrt=y
CONFIG_PACKAGE_luci-theme-bootstrap=n
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_coremark=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
EOF

# 设置模拟环境变量
export GITHUB_ENV="${TMPDIR}/github_env"
export GITHUB_OUTPUT="${TMPDIR}/github_output"
export GITHUB_REPOSITORY="jw10126121/V-OpenWRT-CI"
export GITHUB_RUN_ID="12345678"
export GITHUB_WORKSPACE="${PROJECT_ROOT}"
export WRT_CONFIG="JD-AX6600-WIFI"
export WRT_INFO="jw10126121"
export WRT_SOURCE="jw10126121/immortalwrt"
export WRT_REPO="https://github.com/jw10126121/immortalwrt.git"
export WRT_BRANCH="main"
export WRT_DATE="26.06.09-15.30.00"
export WRT_TARGET="qualcommax_ipq60xx"
export WRT_WIFI="wifi-yes"
export WRT_HASH="468ba22"
export WRT_IP="192.168.1.1"
export WRT_PW="password"
export WRT_SSID="OpenWrt"
export WRT_WORD="12345678"
export WRT_FIREWALL="fw4"
export WRTPackageManager="ipk"
export DEVICE_SUBTARGET="ipq60xx"
export DEVICE_NAME_LIST="jdcloud_re-cs-02"
export DEVICE_NAME_LIST_LIAN="jdcloud_re-cs-02"
export START_TIME="D260609_T153000"
export COMPILE_STATUS="success"
export END_TIME="26.06.09-16.30.00"
export WRT_KVER="6.12.92"

> "${GITHUB_ENV}"
> "${GITHUB_OUTPUT}"

echo "=== 环境变量已设置 ==="
echo "WRT_CONFIG: ${WRT_CONFIG}"
echo "WRT_INFO: ${WRT_INFO}"
echo "WRT_TARGET: ${WRT_TARGET}"
echo "COMPILE_STATUS: ${COMPILE_STATUS}"
echo ""

# 运行通知生成脚本
echo "=== 运行 ci_create_notifications.sh ==="
cd "${TMPDIR}"
bash "${PROJECT_ROOT}/Scripts/ci_create_notifications.sh"

echo ""
echo "=== 生成的通知内容 ==="
echo "--- GITHUB_ENV ---"
cat "${GITHUB_ENV}"
echo ""
echo "--- GITHUB_OUTPUT ---"
cat "${GITHUB_OUTPUT}"
echo ""

# 提取 notify_content 并格式化显示
echo "=== 格式化通知消息 ==="
NOTIFY_CONTENT=$(sed -n '/^notify_content<<EOF$/,/^EOF$/{ /^notify_content<<EOF$/d; /^EOF$/d; p; }' "${GITHUB_ENV}")
echo "${NOTIFY_CONTENT}"
echo ""
echo "=== 测试完成 ==="
