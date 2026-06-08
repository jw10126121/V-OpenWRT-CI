#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译结果通知内容。
# 2. 同时写入 GITHUB_ENV 与 GITHUB_OUTPUT，供后续步骤或 Action 输出复用。

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"

# 查找 .config 文件
find_config_file() {
    local config_file="${1:-.config}"
    if [ ! -f "$config_file" ]; then
        for candidate in "./.config" "${WRT_DIR:-./wrt}/.config"; do
            if [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
        return 1
    fi
    echo "$config_file"
}

config_file="$(find_config_file)" || {
    echo "警告：未找到 .config 文件，跳过通知生成"
    exit 0
}

release_tag="${WRT_CONFIG:-unknown}-${WRT_INFO:-${WRT_SOURCE%%/*}}-${WRT_BRANCH:-main}-${WRT_DATE:-}"
artifact_url="https://github.com/${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}/actions/runs/${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

# 构建固件说明
system_desc=""
{
    echo "【${WRT_INFO:-VIKINGYFY}】"
    echo "固件类型：[常规版]"
    echo "支持平台：${WRT_TARGET:-unknown}"
    echo "源码来源：${WRT_SOURCE:-unknown}"
    echo "源码分支：${WRT_BRANCH:-main}"
    echo "源码HASH：${WRT_HASH:-unknown}"
    echo "默认地址：${WRT_IP:-192.168.10.1}"
    echo "默认密码：${WRT_PW:-无}"
    echo "WIFI名称：${WRT_SSID:-OpenWrt}"
    echo "WIFI密码：${WRT_WORD:-none}"
    echo "内核版本：${WRT_KVER:-unknown}"
} | while IFS= read -r line; do
    system_desc="${system_desc}${line}"$'\n'
done

# 调用 readme.sh 生成带版本号的插件/主题列表
readme_script="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/Scripts/readme.sh"
tmp_desc_file="$(mktemp "${TMPDIR:-/tmp}/notify-desc.XXXXXX.txt")"

bash "${readme_script}" \
    -c "${config_file}" \
    -o "${tmp_desc_file}" \
    -s "${system_desc}" \
    -r 'false'

# 读取 readme.sh 生成的内容
readme_body=""
if [ -f "${tmp_desc_file}" ]; then
    readme_body="$(cat "${tmp_desc_file}")"
    rm -f "${tmp_desc_file}"
fi

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
        if [ -n "${readme_body}" ]; then
            printf '%s\n' "${readme_body}"
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
