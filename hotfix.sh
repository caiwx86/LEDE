#!/bin/bash
echo "execute hotfix.sh"
# 修改内核版本
# sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.6/g' target/linux/rockchip/Makefile

# luci23.05
# 调整 ttyd 到 系统 菜单
sed -i 's/admin\/services/admin\/system/g'  feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/*.json
# 调整 带宽监控 到 网络 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/*.json
# 调整 网络共享 到 NAS 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/*.json
# 调整 UPNP 到 网络 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/*.json
# 调整 Wireguard 到 网络 菜单 
sed -i 's/admin\/status/admin\/network/g'   feeds/luci/protocols/luci-proto-wireguard/root/usr/share/luci/menu.d/*.json
#调整位置
sed -i 's/services/system/g' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i '3 a\\t\t"order": 10,' $(find ./feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/ -type f -name "luci-app-ttyd.json")
sed -i 's/services/network/g' $(find ./feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/ -type f -name "luci-app-upnp.json")
sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-alist/root/usr/share/luci/menu.d/ -type f -name "luci-app-alist.json")
sed -i 's/services/nas/g' $(find ./feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/ -type f -name "luci-app-samba4.json")

PKG_PATH="$OPENWRT_PATH/package/"
#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
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

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

	cd $PKG_PATH && echo "passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
	sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

	cd $PKG_PATH && echo "ssr-plus has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi