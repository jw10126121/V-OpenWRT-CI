#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译开始阶段的多行通知内容。
# 2. 基于当前 .config 动态生成一份带插件列表的说明。

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
    echo "警告：未找到 .config 文件，跳过开始通知生成"
    exit 0
}

# 构建固件说明
system_desc=""
{
    echo "【${WRT_INFO:-VIKINGYFY}】编译开始"
    echo "固件类型：[常规版]"
    echo "支持平台：${WRT_TARGET:-unknown}"
    echo "源码来源：${WRT_SOURCE:-unknown}"
    echo "源码分支：${WRT_BRANCH:-main}"
    echo "默认地址：${WRT_IP:-192.168.10.1}"
    echo "默认密码：${WRT_PW:-无}"
    echo "WIFI名称：${WRT_SSID:-OpenWrt}"
    echo "WIFI密码：${WRT_WORD:-none}"
} | while IFS= read -r line; do
    system_desc="${system_desc}${line}"$'\n'
done

# 调用 readme.sh 生成带版本号的插件/主题列表
readme_script="${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}/Scripts/readme.sh"
tmp_desc_file="$(mktemp "${TMPDIR:-/tmp}/start-notify.XXXXXX.txt")"

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

# 写入开始通知内容
write_start_notify_content() {
    local target_file="$1"

    {
        echo "start_notify_content<<EOF"
        if [ -n "${readme_body}" ]; then
            printf '%s\n' "${readme_body}"
        fi
        echo "EOF"
    } >> "${target_file}"
}

write_start_notify_content "${GITHUB_ENV}"
write_start_notify_content "${GITHUB_OUTPUT}"

echo "【Lin】开始通知内容已生成"
