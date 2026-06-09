#!/bin/bash
# 说明：
# 1. 在 CI 末尾整理编译产物：配置文件、插件列表、固件镜像、安装包压缩包。
# 2. 输出目录 ./upload/ 供 artifact / release 上传使用。
# 3. 命名格式：subtarget_设备名_FW_包管理器_功能_版本_时间

set -euo pipefail

# 由 workflow 注入的环境变量
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${WRT_CONFIG:?WRT_CONFIG is required}"
: "${WRT_INFO:?WRT_INFO is required}"
: "${WRT_BRANCH:?WRT_BRANCH is required}"
: "${WRT_DATE:?WRT_DATE is required}"
: "${WRT_TARGET:?WRT_TARGET is required}"
: "${WRT_WIFI:?WRT_WIFI is required}"
: "${DEVICE_SUBTARGET:?DEVICE_SUBTARGET is required}"
: "${DEVICE_NAME_LIST_LIAN:?DEVICE_NAME_LIST_LIAN is required}"
: "${WRTPackageManager:?WRTPackageManager is required}"

# 构建统一命名前缀
# 格式：subtarget_设备名_FW版本_包管理器_FRP角色_源码版本_编译时间
# 检测 FRP 角色
FRP_TAG="none"
if grep -q "^CONFIG_PACKAGE_luci-app-frpc=y" ./.config 2>/dev/null; then
    if grep -q "^CONFIG_PACKAGE_luci-app-frps=y" ./.config 2>/dev/null; then
        FRP_TAG="FRPC+FRPS"
    else
        FRP_TAG="FRPC"
    fi
elif grep -q "^CONFIG_PACKAGE_luci-app-frps=y" ./.config 2>/dev/null; then
    FRP_TAG="FRPS"
fi

# 构建 BUILD_VARIANT_TAG：防火墙版本_包管理器_FRP功能
BUILD_VARIANT_TAG="${WRT_FIREWALL^^}"
BUILD_VARIANT_TAG="${BUILD_VARIANT_TAG}_${WRTPackageManager}"
[ "$FRP_TAG" != "none" ] && BUILD_VARIANT_TAG="${BUILD_VARIANT_TAG}_${FRP_TAG}"

WRT_REPO_NAME=$(basename "${WRT_REPO:-unknown}" .git 2>/dev/null || echo "unknown")
output_name_prefix="${DEVICE_SUBTARGET}_${DEVICE_NAME_LIST_LIAN}_${BUILD_VARIANT_TAG}_${WRT_REPO_NAME}-${WRT_BRANCH}_${START_TIME:-${WRT_DATE}}"

echo "【Lin】输出命名前缀：${output_name_prefix}"

# 创建上传目录结构
mkdir -p ./upload ./upload/configs

# 导出用户原始配置（make defconfig 之前的版本）
if [ -f ./my_config.txt ]; then
    cp -f ./my_config.txt "./upload/config_${output_name_prefix}.txt"
else
    cp -f ./.config "./upload/config_${output_name_prefix}.txt"
fi

# 保留 defconfig 后的 seed 文件（如果有）
if [ -f ./seed.config ]; then
    cp -f ./seed.config "./upload/config_seed_${output_name_prefix}.txt"
fi

# 提取内核版本和插件列表
manifest=$(find ./bin/targets/ -type f -name "*.manifest" 2>/dev/null | head -1)
if [ -n "$manifest" ]; then
    echo "WRT_KVER=$(grep -oP '^kernel - \K[\d\.]+' "$manifest")" >> "$GITHUB_ENV"
    echo "WRT_LIST=$(grep -oP '^luci-(app|theme)[^ ]*' "$manifest" | tr '\n' ' ')" >> "$GITHUB_ENV"
fi

# 生成编译说明文件（readme）
readme_script="${GITHUB_WORKSPACE}/Scripts/readme.sh"
if [ -f "${readme_script}" ]; then
    chmod +x "${readme_script}"
    bash "${readme_script}" -c "./.config" -o "./upload/readme_${output_name_prefix}.txt" -r 'false'
    echo "【Lin】readme 已生成"
fi

# 清理不需要上传的文件（保留 manifest）
find ./bin/targets/ -iregex ".*\(buildinfo\|json\|sha256sums\|packages\)$" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(initramfs-uImage\).*" -exec rm -rf {} +
find ./bin/targets/ -iregex ".*\(-imagebuilder-\).*" -exec rm -rf {} +

# 整理安装包：收集 ipk/apk 并压缩
tmp_dir="$(mktemp -d)"
find ./bin/packages/ -type f \( -name "*.ipk" -o -name "*.apk" \) 2>/dev/null -exec mv -f {} "${tmp_dir}" \;
find ./bin/targets/ -type f \( -name "*.ipk" -o -name "*.apk" \) 2>/dev/null -exec mv -f {} "${tmp_dir}" \;

# 按分组规则整理安装包，再打成压缩包
if [ -d "${tmp_dir}" ] && [ "$(ls -A "${tmp_dir}" 2>/dev/null)" ]; then
    organize_script="${GITHUB_WORKSPACE}/Scripts/Organize_Packages.sh"
    if [ -f "${organize_script}" ]; then
        chmod +x "${organize_script}"
        bash "${organize_script}" "${tmp_dir}" "./.config"
    fi
    tar -zcf "./upload/Packages_${output_name_prefix}.tar.gz" -C "${tmp_dir}" --transform 's,^./,,' .
fi
rm -rf "${tmp_dir}"

# 整理固件镜像：按设备名重命名后移入 upload/
# 与 LjwOpenWrt 一致，遍历每个设备名进行重命名
for type in ${DEVICE_NAME_LIST:-}; do
    while IFS= read -r file; do
        [ -z "${file}" ] && continue

        # 保留原始扩展名，例如 bin / img.gz / itb
        ext="$(basename "${file}" | cut -d '.' -f 2-)"
        # 从原始文件名中提取"设备名起始后的剩余主体"
        name="$(basename "${file}" | cut -d '.' -f 1 | grep -io "\(${type}\).*")"
        image_kind="${name#${type}-}"
        new_file="${output_name_prefix}_${image_kind}.${ext}"
        mv -f "${file}" "./upload/${new_file}"
    done < <(find ./bin/targets/ -type f -iname "*${type}*.*")
done

# 兜底搬运剩余目标文件（如 manifest 等）
find ./bin/targets/ -type f -not -name '*openwrt-imagebuilder*' -exec mv -f {} ./upload/ \;

# 释放磁盘空间（替代 make clean，避免在 organize 之前清理导致 packages 丢失）
rm -rf ./build_dir ./staging_dir ./tmp ./dl ./feeds

echo "【Lin】编译产物整理完成，upload/ 目录内容："
ls -lh ./upload/
