#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=$(basename "$PKG_REPO" .git)

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "【Lin】Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "【Lin】Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "【Lin】Not found directory: $NAME"
		fi
	done

	# 克隆仓库（支持完整 URL 或 GitHub shorthand）
	if [[ "$PKG_REPO" =~ ^https?:// ]]; then
		local CLONE_URL="$PKG_REPO"
	else
		local CLONE_URL="https://github.com/$PKG_REPO.git"
	fi
	echo "【Lin】Clone: $CLONE_URL ($PKG_BRANCH)"
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "$CLONE_URL"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
	echo "【Lin】Downloaded: $PKG_NAME"
}

# 从一个仓库中提取多个子包目录（适用于一个仓库维护多个插件的场景）
# UPDATE_PACKAGE_LIST "pkg1 pkg2 pkg3" "owner/repo" "branch"
UPDATE_PACKAGE_LIST() {
	local PKG_LIST=($1)
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local REPO_NAME=${PKG_REPO#*/}
	local TMP_DIR="pkglist_${REPO_NAME}"

	echo " "

	# 删除所有同名旧包
	for NAME in "${PKG_LIST[@]}"; do
		echo "【Lin】Search directory: $NAME"
		local FOUND_DIRS=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "$NAME" 2>/dev/null)
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "【Lin】Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "【Lin】Not found directory: $NAME"
		fi
	done

	# 临时克隆仓库
	echo "【Lin】Clone: $PKG_REPO ($PKG_BRANCH)"
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" "$TMP_DIR"

	# 逐个复制目标目录到 package/
	for NAME in "${PKG_LIST[@]}"; do
		if [ -d "./$TMP_DIR/$NAME" ]; then
			cp -rf "./$TMP_DIR/$NAME" ./
			echo "【Lin】Copied: $NAME"
		else
			echo "【Lin】Warning: $NAME not found in repository"
		fi
	done

	# 删除临时仓库
	rm -rf "./$TMP_DIR"
	echo "【Lin】Package list downloaded: ${PKG_LIST[*]}"
}

# 修复 pushbot 运行时兼容性（CPU温度、网络测试URL）
fix_pushbot() {
	local pushbot_dir pushbot_file
	pushbot_dir=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-pushbot" -prune)
	[ -n "$pushbot_dir" ] && [ -f "$pushbot_dir/root/usr/bin/pushbot/pushbot" ] || return 0

	pushbot_file="$pushbot_dir/root/usr/bin/pushbot/pushbot"
	sed -i 's/local cputemp=`soc_temp`/local cputemp=`tempinfo`/' "$pushbot_file"
	sed -i 's/CPU：\${cputemp}℃/\${cputemp}/' "$pushbot_file"
	sed -i "s| https://www.qidian.com https://www.douban.com||g" "$pushbot_file"
	echo "【Lin】pushbot has been fixed!"
}

# 修复 wechatpush 运行时兼容性（禁用硬盘检查、CPU温度、钉钉模板）
fix_wechatpush() {
	local wechatpush_dir wechatpush_file
	wechatpush_dir=$(find ./*/ -maxdepth 3 -type d -iname "luci-app-wechatpush" -prune)
	[ -n "$wechatpush_dir" ] && [ -f "$wechatpush_dir/root/usr/share/wechatpush/wechatpush" ] || return 0

	wechatpush_file="$wechatpush_dir/root/usr/share/wechatpush/wechatpush"
	sed -i '/^#/!{/^[[:blank:]]*\[ -z "\$1" \] && get_disk/s/^[[:blank:]]*/#&/;}' "$wechatpush_file"
	sed -i '\|>"\$output_dir/cputemp"|s/soc_temp/tempinfo/g' "$wechatpush_file"
	sed -i 's/$(translate "CPU:") ${cputemp}℃/${cputemp}/g' "$wechatpush_file"

	# 复制钉钉推送模板
	[ -f "$GITHUB_WORKSPACE/Scripts/patch/wechatpush_diy.json" ] && \
		cp -p "$GITHUB_WORKSPACE/Scripts/patch/wechatpush_diy.json" "$wechatpush_dir/root/usr/share/wechatpush/api/diy.json"
	echo "【Lin】wechatpush has been fixed!"
}

# 修复 frpc/frps init 脚本执行权限
ensure_luci_app_frp_init_permissions() {
	local init_file

	for init_file in \
		"./luci-app-frpc/root/etc/init.d/frpc" \
		"./luci-app-frps/root/etc/init.d/frps"; do
		if [ -f "${init_file}" ]; then
			chmod 0755 "${init_file}"
			echo "【Lin】已补齐执行权限：${init_file}"
		fi
	done
}

# 安全替换软件包（失败自动回滚）
safe_update_package() {
	local package_name=$1
	local package_repo=$2
	local package_branch=$3
	local path_default
	local path_default_bak

	# 支持完整 URL 或 GitHub shorthand
	if [[ "$package_repo" =~ ^https?:// ]]; then
		local clone_url="$package_repo"
	else
		local clone_url="https://github.com/$package_repo.git"
	fi

	path_default=$(find ./ ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "${package_name}" -prune)
	path_default_bak="${path_default}_bak"
	[ -d "${path_default_bak}" ] && rm -rf "${path_default_bak}"

	[ -d "${path_default}" ] && mv -f "${path_default}" "${path_default_bak}" && \
		echo "【Lin】备份${package_name}：${path_default} -> ${path_default_bak}"

	git clone --depth=1 --single-branch -b "${package_branch}" "${clone_url}" "${path_default}"
	if [ -d "${path_default}" ]; then
		echo "【Lin】替换${package_name}成功：${path_default}"
		[ -d "${path_default_bak}" ] && rm -rf "${path_default_bak}"
	else
		mv -f "${path_default_bak}" "${path_default}"
		echo "【Lin】替换${package_name}失败，还原${package_name}"
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"
#UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "luci-theme-noobwrt" "nooblk-98/luci-theme-noobwrt" "master"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "luci-app-onliner" "danchexiaoyang/luci-app-onliner" "main"
UPDATE_PACKAGE "luci-app-easytier" "EasyTier/luci-app-easytier" "v2.6.4"
# luci-app-vlmcsd：LEDE专用，IMM用自带的
# UPDATE_PACKAGE_LIST "luci-app-vlmcsd vlmcsd" "sbwml/openwrt_pkgs" "main"

UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
fix_pushbot

UPDATE_PACKAGE "luci-app-wechatpush" "tty228/luci-app-wechatpush" "master"
fix_wechatpush

UPDATE_PACKAGE "luci-app-socat" "Lienol/openwrt-package" "main"
UPDATE_PACKAGE "luci-app-sqm" "https://git.cooluc.com/sbwml/luci-app-sqm" "main"

safe_update_package "frp" "https://github.com/jw10126121/openwrt_frp" "v0.69.0"
UPDATE_PACKAGE_LIST "luci-app-frpc luci-app-frps" "superzjg/luci-app-frpc_frps" "main"
ensure_luci_app_frp_init_permissions

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

UPDATE_PACKAGE "athena-led" "unraveloop/JDC-AX6600-Athena-LED-Controller" "main"
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 从 coolsnowwolf/openwrt 获取 verysync
UPDATE_PACKAGE_LIST "luci-app-verysync verysync" "coolsnowwolf/openwrt" "master"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
