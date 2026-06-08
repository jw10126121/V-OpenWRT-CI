#!/bin/bash
# 说明：
# 1. 在 CI 末尾整理编译产物：配置文件、插件列表、固件镜像。
# 2. 输出目录 ./upload/ 供 artifact / release 上传使用。

set -euo pipefail

# 由 workflow 注入的环境变量
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${WRT_CONFIG:?WRT_CONFIG is required}"
: "${WRT_INFO:?WRT_INFO is required}"
: "${WRT_BRANCH:?WRT_BRANCH is required}"
: "${WRT_DATE:?WRT_DATE is required}"
: "${WRT_TARGET:?WRT_TARGET is required}"
: "${WRT_WIFI:?WRT_WIFI is required}"

# 创建上传目录结构
mkdir -p ./upload ./upload/configs

# 导出配置文件
cp -f ./.config "./upload/configs/Config-${WRT_CONFIG}-${WRT_INFO}-${WRT_BRANCH}-${WRT_DATE}.txt"

# 保留 defconfig 后的 seed 文件（如果有）
if [ -f ./seed.config ]; then
    cp -f ./seed.config "./upload/configs/seed-${WRT_CONFIG}-${WRT_INFO}-${WRT_BRANCH}-${WRT_DATE}.txt"
fi

# 提取内核版本和插件列表
manifest=$(find ./bin/targets/ -type f -name "*.manifest" 2>/dev/null | head -1)
if [ -n "$manifest" ]; then
    echo "WRT_KVER=$(grep -oP '^kernel - \K[\d\.]+' "$manifest")" >> "$GITHUB_ENV"
    echo "WRT_LIST=$(grep -oP '^luci-(app|theme)[^ ]*' "$manifest" | tr '\n' ' ')" >> "$GITHUB_ENV"
fi

# 清理不需要上传的文件
find ./bin/targets/ -iregex ".*\(buildinfo\|json\|sha256sums\|packages\)$" -exec rm -rf {} +

# 整理固件镜像：按设备名重命名后移入 upload/
for FILE in $(find ./bin/targets/ -type f -iname "*${WRT_TARGET}*"); do
    EXT=$(basename "$FILE" | cut -d '.' -f 2-)
    NAME=$(basename "$FILE" | cut -d '.' -f 1 | grep -io "\(${WRT_TARGET}\).*")
    NEW_FILE="${NAME}-${WRT_INFO}-${WRT_BRANCH}-${WRT_WIFI}-${WRT_DATE}.${EXT}"
    mv -f "$FILE" "./upload/${NEW_FILE}"
done

# 兜底搬运剩余目标文件（如 .bin 等）
find ./bin/targets/ -type f -exec mv -f {} ./upload/ \;

echo "编译产物整理完成，upload/ 目录内容："
ls -lh ./upload/
