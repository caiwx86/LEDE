#!/usr/bin/env bash
echo "execute diy-script.sh"
#自定义所有设置
WRT_IP=10.0.10.1
WRT_THEME=argon
WRT_NAME=LEDE

echo "当前网关IP: $WRT_IP"
# 修改内核版本
sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.12/g' target/linux/qualcommax/Makefile 

update_feeds() {
    FEEDS_CONF="$OPENWRT_PATH/feeds.conf.default"
    # 删除注释行
    sed -i '/^#/d' "$FEEDS_CONF"

    # 检查并添加 small-package 源
    if ! grep -q "small-package" "$FEEDS_CONF"; then
        # 确保文件以换行符结尾
        [ -z "$(tail -c 1 "$FEEDS_CONF")" ] || echo "" >>"$FEEDS_CONF"
        echo "src-git small8 https://github.com/kenzok8/small-package" >>"$FEEDS_CONF"
    fi
    
    # 更新 feeds
    ./scripts/feeds update -a
}

remove_unwanted_packages() {
    local luci_packages=(
        "luci-app-passwall" "luci-app-smartdns" "luci-app-ddns-go" "luci-app-rclone"
        "luci-app-ssr-plus" "luci-app-vssr" "luci-theme-argon" "luci-app-daed" "luci-app-dae"
        "luci-app-alist" "luci-app-argon-config" "luci-app-homeproxy" "luci-app-haproxy-tcp"
        "luci-app-openclash" "luci-app-mihomo" "luci-app-appfilter" "luci-app-msd_lite"
    )
    local packages_net=(
        "xray-core" "xray-plugin" "dns2socks" "alist" "hysteria"
        "smartdns" "mosdns" "adguardhome" "ddns-go" "naiveproxy" "shadowsocks-rust"
        "sing-box" "v2ray-core" "v2ray-geodata" "v2ray-plugin" "tuic-client"
        "chinadns-ng" "ipt2socks" "tcping" "trojan-plus" "simple-obfs"
        "shadowsocksr-libev" "dae" "daed" "mihomo" "geoview" "tailscale" "open-app-filter"
    )
    local small8_packages=(
        "ppp" "firewall" "dae" "daed" "daed-next" "libnftnl" "nftables" "dnsmasq" "haproxy" "luci-app-daed"
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
        luci-theme-argon luci-theme-argon-config easytier luci-app-easytier nps luci-app-npc luci-app-ssr-plus \
        msd_lite luci-app-msd_lite
}

install_feeds() {
    ./scripts/feeds update -a
    for dir in $OPENWRT_PATH/feeds/*; do
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

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

fix_default_set() {
    # 修改默认主题
    if [ -d "$OPENWRT_PATH/feeds/luci/collections/" ]; then
        find "$OPENWRT_PATH/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} \;
    fi

    if [ -d "$OPENWRT_PATH/feeds/small8/luci-theme-argon" ]; then
        find "$OPENWRT_PATH/feeds/small8/luci-theme-argon" -type f -name "cascade*" -exec sed -i 's/--bar-bg/--primary/g' {} \;
    fi

    install -Dm755 "$GITHUB_WORKSPACE/scripts/patch/99_set_argon_primary" "$OPENWRT_PATH/package/base-files/files/etc/uci-defaults/99_set_argon_primary"

    echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> $OPENWRT_PATH/.config
}

update_default_lan_addr() {
    local CFG_PATH="$OPENWRT_PATH/package/base-files/luci2/bin/config_generate"

    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$WRT_IP'/g' $CFG_PATH
        sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_PATH
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

function add_amlogic() {
    if [[ $AMLOGIC == "true" ]]; then
        # 晶晨宝盒
        # git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
        sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/caiwx86/OpenWrt'|g" package/kenzok8/luci-app-amlogic/root/etc/config/amlogic
        sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" package/kenzok8/luci-app-amlogic/root/etc/config/amlogic
        sed -i "s|shared_fstype.*|shared_fstype 'btrfs'|g" package/kenzok8/luci-app-amlogic/root/etc/config/amlogic
        #sed -i "s|ARMv8|ARMv8_PLUS|g" package/luci-app-amlogic/root/etc/config/amlogic
        echo CONFIG_PACKAGE_luci-app-amlogic=y >>  $OPENWRT_PATH/.config
    fi
}

function set_menu_app() {
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
}

function remove_lede_package() {
    # 移除不需要的包
    rm -rf feeds/luci/themes/{luci-theme-argon,luci-theme-netgear}
    rm -rf feeds/packages/net/{mosdns,smartdns,v2ray-geodata}
    rm -rf feeds/luci/applications/{luci-app-vlmcsd,luci-app-accesscontrol,luci-app-ddns,luci-app-wol,luci-app-kodexplorer}
    rm -rf feeds/luci/applications/{luci-app-smartdns,luci-app-v2raya,luci-app-mosdns,luci-app-serverchan,luci-app-passwall2}
}

function set_other() {

    # 添加NSS/12大内核支持等
    chmod +x $GITHUB_WORKSPACE/scripts/function.sh && $GITHUB_WORKSPACE/scripts/function.sh

    # 在线用户
    git_sparse_clone main https://github.com/danchexiaoyang/luci-app-onliner luci-app-onliner 

    # adguardhome
    bash $GITHUB_WORKSPACE/scripts/preset-adguardhome.sh

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

    # DNSMASQ DNSSERVER
    sed -i 's/DNS_SERVERS=\"\"/DNS_SERVERS=\"223.5.5.5 8.8.4.4\"/g' package/network/services/dnsmasq/files/dnsmasq.init
}

update_and_install_feeds() {
    echo "Updating and installing feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
}

main() {
    echo "main() begin..."
    update_feeds
    remove_unwanted_packages
    fix_default_set
    update_default_lan_addr
    add_backup_info_to_sysupgrade
    add_amlogic
    set_menu_app
    remove_lede_package
    set_other
    update_and_install_feeds
    # install_feeds
    echo "main() end..."
}

main "$@"
