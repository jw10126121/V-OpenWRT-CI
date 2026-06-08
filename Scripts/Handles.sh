#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# 预置 HomeProxy 规则数据（默认关闭，需要时改为 true）
PRELOAD_HOMEPROXY=false

### --- 预置方法 --- ###

# 预置 HomeProxy 规则数据
preload_homeproxy() {
	[ "$PRELOAD_HOMEPROXY" = true ] || return 0
	[ -d *"homeproxy"* ] || return 0

	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "【Lin】homeproxy date has been updated!"
}

### --- 主题修复方法 --- ###

# 修改 argon 主题字体和颜色
fix_theme_argon() {
	[ -d *"luci-theme-argon"* ] || return 0
	cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "【Lin】theme-argon has been fixed!"
}

# 修改 aurora 菜单式样
fix_theme_aurora() {
	[ -d *"luci-app-aurora-config"* ] || return 0
	cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "【Lin】theme-aurora has been fixed!"
}

### --- 插件修复方法 --- ###

# 修改 mini-diskmanager 菜单位置
fix_mini_diskmanager() {
	[ -d *"luci-app-mini-diskmanager"* ] || return 0
	cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "【Lin】mini-diskmanager has been fixed!"
}

# 修复 TailScale 配置文件冲突
fix_tailscale() {
	local ts_file
	ts_file=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
	[ -f "$ts_file" ] || return 0

	sed -i '/\/files/d' "$ts_file"

	cd $PKG_PATH && echo "【Lin】tailscale has been fixed!"
}

# 修复 Rust 编译失败
fix_rust() {
	local rust_file
	rust_file=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
	[ -f "$rust_file" ] || return 0

	sed -i 's/ci-llvm=true/ci-llvm=false/g' "$rust_file"

	cd $PKG_PATH && echo "【Lin】rust has been fixed!"
}

### --- 执行 --- ###

preload_homeproxy
fix_theme_argon
fix_theme_aurora
fix_mini_diskmanager
fix_tailscale
fix_rust
