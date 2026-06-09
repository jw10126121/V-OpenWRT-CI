#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译开始阶段的多行通知内容。
# 2. 优先使用预生成的 readme 文件，回退到动态生成。

set -uo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# 从 .config 提取设备架构
get_device_arch() {
    local config_file="${1:-.config}"
    local arch=""
    if grep -q "CONFIG_TARGET_armvirt" "${config_file}" 2>/dev/null; then
        arch="aarch64_cortex-a53"
    elif grep -q "CONFIG_TARGET_mediatek" "${config_file}" 2>/dev/null; then
        arch="aarch64_cortex-a53"
    elif grep -q "CONFIG_TARGET_qualcommax" "${config_file}" 2>/dev/null; then
        arch="aarch64_cortex-a53"
    elif grep -q "CONFIG_TARGET_ramips" "${config_file}" 2>/dev/null; then
        arch="mipsel_24kc"
    elif grep -q "CONFIG_TARGET_x86" "${config_file}" 2>/dev/null; then
        arch="x86_64"
    elif grep -q "CONFIG_TARGET_rockchip" "${config_file}" 2>/dev/null; then
        arch="aarch64_cortex-a53"
    fi
    echo "${arch}"
}

# 查找 .config 文件
config_file="$(find ./ -maxdepth 2 -name ".config" -type f 2>/dev/null | head -1)"
[ -z "${config_file}" ] && config_file="./.config"

# 构建固件信息摘要
DEVICE_ARCH="$(get_device_arch "${config_file}")"
WRT_REPO_NAME=$(basename "${WRT_REPO:-unknown}" .git 2>/dev/null || echo "unknown")

system_info="【${WRT_INFO:-unknown}】编译开始
支持设备：${DEVICE_NAME_LIST:-unknown}
固件类型：[${WRT_FIREWALL:-fw4}]
支持平台：${WRT_TARGET:-unknown}
源码风味：${WRT_REPO_NAME}
FW环境：${WRT_FIREWALL:-fw4}
设备架构：${DEVICE_ARCH}
包管理器：${WRTPackageManager:-ipk}
默认地址：${WRT_IP:-192.168.0.1}
默认密码：${WRT_PW:-无}
是否wifi：$(echo "${WRT_WIFI:-}" | grep -q "yes" && echo "有WIFI" || echo "无WIFI")
源码地址：${WRT_REPO:-unknown}
源码分支：${WRT_BRANCH:-main}"

# 优先使用预生成的 readme 文件
get_start_notify_body() {
    if [ -n "${readme_desc_file:-}" ] && [ -f "${readme_desc_file}" ]; then
        cat "${readme_desc_file}"
        return 0
    fi

    # 回退：直接调用 readme.sh
    local cfg="${config_file}"
    [ -z "${cfg}" ] || [ ! -f "${cfg}" ] && return 1

    local readme_script="${GITHUB_WORKSPACE}/Scripts/readme.sh"
    [ -f "${readme_script}" ] || return 1

    local tmp_desc_file
    tmp_desc_file="$(mktemp)"
    bash "${readme_script}" -c "${cfg}" -o "${tmp_desc_file}" -s "${system_info}" -r 'false'
    if [ -f "${tmp_desc_file}" ] && [ -s "${tmp_desc_file}" ]; then
        cat "${tmp_desc_file}"
    fi
    rm -f "${tmp_desc_file}"
}

start_notify_body="$(get_start_notify_body)"

# 写入开始通知内容
write_start_notify_content() {
    local target_file="$1"

    {
        echo "start_notify_content<<EOF"
        if [ -n "${start_notify_body}" ]; then
            printf '%s\n' "${start_notify_body}"
        fi
        echo "EOF"
    } >> "${target_file}"
}

write_start_notify_content "${GITHUB_ENV}"
write_start_notify_content "${GITHUB_OUTPUT}"

echo "【Lin】开始通知内容已生成"
