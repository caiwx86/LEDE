#!/bin/bash
echo "execute diy-script.sh"
#自定义所有设置
WRT_IP=10.0.10.1
WRT_THEME=argon
WRT_NAME=LEDE

echo "当前网关IP: $WRT_IP"
# 支持 ** 查找子目录
shopt -s globstar

# hotfix
bash $GITHUB_WORKSPACE/hotfix.sh

# 添加NSS/12大内核支持等
chmod +x $GITHUB_WORKSPACE/scripts/function.sh && $GITHUB_WORKSPACE/scripts/function.sh

update_feeds() {
    FEEDS_CONF="feeds.conf.default"
    # 删除注释行
    sed -i '/^#/d' "$FEEDS_CONF"

    # 检查并添加 small-package 源
    if ! grep -q "small-package" "$FEEDS_CONF"; then
        # 确保文件以换行符结尾
        [ -z "$(tail -c 1 "$FEEDS_CONF")" ] || echo "" >>"$FEEDS_CONF"
        echo "src-git small8 https://github.com/kenzok8/small-package" >>"$FEEDS_CONF"
    fi
    
    # 更新 feeds
    ./scripts/feeds clean
    ./scripts/feeds update -a
}

remove_unwanted_packages() {
    local luci_packages=(
        "luci-app-passwall" "luci-app-smartdns" "luci-app-ddns-go" "luci-app-rclone"
        "luci-app-ssr-plus" "luci-app-vssr" "luci-theme-argon" "luci-app-daed" "luci-app-dae"
        "luci-app-alist" "luci-app-argon-config" "luci-app-homeproxy" "luci-app-haproxy-tcp"
        "luci-app-openclash" "luci-app-mihomo" "luci-app-appfilter"
    )
    local packages_net=(
        "xray-core" "xray-plugin" "dns2socks" "alist" "hysteria"
        "smartdns" "mosdns" "adguardhome" "ddns-go" "naiveproxy" "shadowsocks-rust"
        "sing-box" "v2ray-core" "v2ray-geodata" "v2ray-plugin" "tuic-client"
        "chinadns-ng" "ipt2socks" "tcping" "trojan-plus" "simple-obfs"
        "shadowsocksr-libev" "dae" "daed" "mihomo" "geoview" "tailscale" "open-app-filter"
    )
    local small8_packages=(
        "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" "dnsmasq" "haproxy"
    )

    for pkg in "${luci_packages[@]}"; do
        \rm -rf ./feeds/luci/applications/$pkg
        \rm -rf ./feeds/luci/themes/$pkg
    done

    for pkg in "${packages_net[@]}"; do
        \rm -rf ./feeds/packages/net/$pkg
    done

    for pkg in "${small8_packages[@]}"; do
        \rm -rf ./feeds/small8/$pkg
    done
}

install_small8() {
    ./scripts/feeds install -p small8 -f xray-core xray-plugin dns2tcp dns2socks haproxy hysteria \
        naiveproxy shadowsocks-rust sing-box v2ray-core v2ray-geodata v2ray-geoview v2ray-plugin \
        tuic-client chinadns-ng ipt2socks tcping trojan-plus simple-obfs shadowsocksr-libev \
        luci-app-passwall alist luci-app-alist smartdns luci-app-smartdns v2dat mosdns luci-app-mosdns \
        adguardhome luci-app-adguardhome ddns-go luci-app-ddns-go taskd luci-lib-xterm luci-lib-taskd \
        luci-app-store quickstart luci-app-quickstart luci-app-istorex luci-app-cloudflarespeedtest \
        netdata luci-app-netdata lucky luci-app-lucky luci-app-openclash luci-app-homeproxy \
        luci-app-amlogic nikki luci-app-nikki tailscale luci-app-tailscale oaf open-app-filter luci-app-oaf \
        luci-theme-argon luci-theme-argon-config easytier luci-app-easytier nps luci-app-npc luci-app-ssr-plus
}

install_feeds() {
    ./scripts/feeds update -i
    for dir in $BUILD_DIR/feeds/*; do
        # 检查是否为目录并且不以 .tmp 结尾，并且不是软链接
        if [ -d "$dir" ] && [[ ! "$dir" == *.tmp ]] && [ ! -L "$dir" ]; then
            if [[ $(basename "$dir") == "small8" ]]; then
                install_small8
            else
                ./scripts/feeds install -f -ap $(basename "$dir")
            fi
        fi
    done
}

fix_default_set() {
    # 修改默认主题
    if [ -d "./feeds/luci/collections/" ]; then
        find "./feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    if [ -d "./feeds/small8/luci-theme-argon" ]; then
        find "./feeds/small8/luci-theme-argon" -type f -name "cascade*" -exec sed -i 's/--bar-bg/--primary/g' {} \;
    fi

    install -Dm755 "$GITHUB_WORKSPACE/scripts/patch/99_set_argon_primary" "./package/base-files/files/etc/uci-defaults/99_set_argon_primary"
}

update_default_lan_addr() {
    local CFG_PATH="./package/base-files/luci2/bin/config_generate"

    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$WRT_IP'/g' $CFG_PATH
    fi
}

# 添加系统升级时的备份信息
function add_backup_info_to_sysupgrade() {
    local conf_path="$BUILD_DIR/package/base-files/files/etc/sysupgrade.conf"

    if [ -f "$conf_path" ]; then
        cat >"$conf_path" <<'EOF'
/etc/AdGuardHome.yaml
/etc/easytier
/etc/lucky/
EOF
    fi
}

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
fi
#LEDE平台调整
CFG_FILE_LEDE="./package/base-files/luci2/bin/config_generate"
if [ -f "$CFG_FILE_LEDE" ]; then
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE_LEDE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE_LEDE
fi

WRT_IPPART=$(echo $WRT_IP | cut -d'.' -f1-3)
#修复Openvpnserver无法连接局域网和外网问题
if [ -f "./package/network/config/firewall/files/firewall.user" ]; then
    echo "iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o br-lan -j MASQUERADE" >> ./package/network/config/firewall/files/firewall.user
    echo "OpenVPN Server has been fixed and is now accessible on the network!"
fi
#修复Openvpnserver默认配置的网关地址与无法多终端同时连接问题
if [ -f "./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn" ]; then
    echo "	option duplicate_cn '1'" >> ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed to resolve the issue of duplicate connecting!"
    sed -i "s/192.168.1.1/$WRT_IPPART.1/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    sed -i "s/192.168.1.0/$WRT_IPPART.0/g" ./package/feeds/luci/luci-app-openvpn-server/root/etc/config/openvpn
    echo "OpenVPN Server has been fixed the default gateway address!"
fi
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config

# 更改默认 Shell 为 zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# 修改 Docker 路径
if [ -f "package/luci-app-docker/root/etc/docker/daemon.json" ]; then
sed -i "s|\"data-root\": \"/opt/\",|\"data-root\": \"/opt/docker/\",|" package/luci-app-docker/root/etc/docker/daemon.json
fi
if [ -f "feeds/luci/applications/luci-app-docker/root/etc/docker/daemon.json" ]; then
sed -i "s|\"data-root\": \"/opt/\",|\"data-root\": \"/opt/docker/\",|" feeds/luci/applications/luci-app-docker/root/etc/docker/daemon.json
fi

# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Caiwx/g" package/lean/default-settings/files/zzz-default-settings

# 修复 armv8 设备 xfsprogs 报错
sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修改 Makefile
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# 取消主题默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# DNSMASQ DNSSERVER
sed -i 's/DNS_SERVERS=\"\"/DNS_SERVERS=\"223.5.5.5 8.8.4.4\"/g' package/network/services/dnsmasq/files/dnsmasq.init

main() {
    update_feeds
    remove_unwanted_packages
    fix_default_set
    update_default_lan_addr
    add_backup_info_to_sysupgrade
    install_feeds
}

main "$@"