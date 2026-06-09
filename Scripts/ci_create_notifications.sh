#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译结果通知内容。
# 2. 同时写入 GITHUB_ENV 与 GITHUB_OUTPUT，供后续步骤或 Action 输出复用。
# 3. 优先使用 ci_organize_outputs.sh 预生成的 readme 文件。

set -uo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

release_tag="${WRT_CONFIG:-unknown}-${WRT_INFO:-${WRT_SOURCE%%/*}}-${WRT_BRANCH:-main}-${WRT_DATE:-}"
artifact_url="https://github.com/${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}/actions/runs/${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

# 从 .config 提取设备架构
get_device_arch() {
    local config_file="${1:-.config}"
    local arch=""
    # 从 TARGET 個推断架构
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

# 检测 FRP 角色
get_frp_role() {
    local config_file="${1:-.config}"
    local frp_role="未集成"
    if grep -q "^CONFIG_PACKAGE_luci-app-frpc=y" "${config_file}" 2>/dev/null; then
        if grep -q "^CONFIG_PACKAGE_luci-app-frps=y" "${config_file}" 2>/dev/null; then
            frp_role="FRPC+FRPS"
        else
            frp_role="FRPC"
        fi
    elif grep -q "^CONFIG_PACKAGE_luci-app-frps=y" "${config_file}" 2>/dev/null; then
        frp_role="FRPS"
    fi
    echo "${frp_role}"
}

# 查找 .config 文件
config_file="$(find ./ -maxdepth 2 -name ".config" -type f 2>/dev/null | head -1)"
[ -z "${config_file}" ] && config_file="./.config"

# 构建固件信息摘要
DEVICE_ARCH="$(get_device_arch "${config_file}")"
FRP_ROLE="$(get_frp_role "${config_file}")"
WRT_REPO_NAME=$(basename "${WRT_REPO:-unknown}" .git 2>/dev/null || echo "unknown")

system_info="【${WRT_INFO:-unknown}】
支持设备：${DEVICE_NAME_LIST:-unknown}
固件类型：[${WRT_FIREWALL:-fw4}]
支持平台：${WRT_TARGET:-unknown}
源码风味：${WRT_REPO_NAME}
FW环境：${WRT_FIREWALL:-fw4}
FRP角色：${FRP_ROLE}
设备架构：${DEVICE_ARCH}
内核版本：${WRT_KVER:-unknown}
包管理器：${WRTPackageManager:-ipk}
默认地址：${WRT_IP:-192.168.0.1}
默认密码：${WRT_PW:-无}
是否wifi：$(echo "${WRT_WIFI:-}" | grep -q "yes" && echo "有WIFI" || echo "无WIFI")
源码地址：${WRT_REPO:-unknown}
源码分支：${WRT_BRANCH:-main}
源码hash：${WRT_HASH:-unknown}"

# 优先使用预生成的 readme 文件（由 ci_organize_outputs.sh 导出）
get_notify_body() {
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

notify_body="$(get_notify_body)"

# 写入通知内容
write_notify_content() {
    local target_file="$1"

    {
        echo "notify_content<<EOF"
        if [ "${COMPILE_STATUS:-unknown}" = "success" ]; then
            echo "Release下载地址：https://github.com/${GITHUB_REPOSITORY}/releases/tag/${release_tag}"
            echo "Artifact下载地址：${artifact_url}"
            echo ""
        fi
        if [ -n "${notify_body}" ]; then
            printf '%s\n' "${notify_body}"
        fi
        echo ""
        echo "编译状态：${COMPILE_STATUS:-unknown}"
        echo "编译结束：${END_TIME:-}"
        echo "EOF"
    } >> "${target_file}"
}

write_notify_content "${GITHUB_ENV}"
write_notify_content "${GITHUB_OUTPUT}"

echo "【Lin】通知内容已生成"
