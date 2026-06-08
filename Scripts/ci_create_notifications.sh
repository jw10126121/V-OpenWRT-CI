#!/bin/bash
# 说明：
# 1. 在 GitHub Actions 中生成编译结果通知内容。
# 2. 写入 GITHUB_ENV 供后续步骤使用。

set -euo pipefail

: "${GITHUB_ENV:?GITHUB_ENV is required}"

# 获取插件列表
get_plugin_list() {
    local config_file="${1:-.config}"
    if [ -f "$config_file" ]; then
        grep "^CONFIG_PACKAGE_luci-app-.*=y$" "$config_file" | \
            sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//' | \
            sed 's/luci-app-//' | tr '\n' ' '
    fi
}

# 获取主题列表
get_theme_list() {
    local config_file="${1:-.config}"
    if [ -f "$config_file" ]; then
        grep "^CONFIG_PACKAGE_luci-theme-.*=y$" "$config_file" | \
            sed 's/^CONFIG_PACKAGE_//' | sed 's/=y$//' | \
            sed 's/luci-theme-//' | tr '\n' ' '
    fi
}

# 生成通知内容
get_notify_body() {
    local compile_status="${COMPILE_STATUS:-unknown}"
    local end_time="${END_TIME:-}"
    local config_name="${WRT_CONFIG:-unknown}"
    local device_target="${WRT_TARGET:-unknown}"
    local source_info="${WRT_SOURCE:-unknown}"
    local branch_info="${WRT_BRANCH:-unknown}"
    local ip_addr="${WRT_IP:-192.168.1.1}"
    local ssid_name="${WRT_SSID:-OpenWrt}"
    local artifact_url="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
    local release_tag="${WRT_CONFIG}-${WRT_INFO:-${WRT_SOURCE%%/*}}-${WRT_BRANCH}-${WRT_DATE}"

    # 获取插件和主题列表
    local plugin_list=$(get_plugin_list)
    local theme_list=$(get_theme_list)

    cat << EOF
=====================================
     OpenWrt 编译结果通知
=====================================

📋 编译信息：
  • 配置名称：${config_name}
  • 设备平台：${device_target}
  • 源码来源：${source_info}
  • 源码分支：${branch_info}

⏰ 编译时间：
  • 结束时间：${end_time}

🌐 访问信息：
  • 默认地址：${ip_addr}
  • WIFI名称：${ssid_name}
  • 默认密码：无

📦 固件下载：
  • Artifact：${artifact_url}
  • Release：https://github.com/${GITHUB_REPOSITORY}/releases/tag/${release_tag}

🔧 已集成插件：
  ${plugin_list:-无}

🎨 已集成主题：
  ${theme_list:-无}

📊 编译状态：${compile_status}
EOF
}

# 写入环境变量
notify_body="$(get_notify_body)"

{
    echo "notify_content<<EOF"
    printf '%s\n' "${notify_body}"
    echo "EOF"
} >> "${GITHUB_ENV}"

echo "通知内容已生成"
