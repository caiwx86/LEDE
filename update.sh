#!/usr/bin/env bash

set -e
set -o errexit
set -o errtrace

# 定义错误处理函数
error_handler() {
    echo "Error occurred in script at line: ${BASH_LINENO[0]}, command: '${BASH_COMMAND}'"
}

# 设置trap捕获ERR信号
trap 'error_handler' ERR

source /etc/profile
BASE_PATH=$(cd $(dirname $0) && pwd)

REPO_URL=$1
REPO_BRANCH=$2
BUILD_DIR=$3
COMMIT_HASH=$4

FEEDS_CONF="feeds.conf.default"
GOLANG_REPO="https://github.com/sbwml/packages_lang_golang"
GOLANG_BRANCH="24.x"
THEME_SET="argon"
LAN_ADDR="10.0.10.1"

clean_up() {
    cd $BUILD_DIR
    if [[ -f $BUILD_DIR/.config ]]; then
        \rm -f $BUILD_DIR/.config
    fi
    if [[ -d $BUILD_DIR/tmp ]]; then
        \rm -rf $BUILD_DIR/tmp
    fi
    if [[ -d $BUILD_DIR/logs ]]; then
        \rm -rf $BUILD_DIR/logs/*
    fi
    mkdir -p $BUILD_DIR/tmp
    echo "1" >$BUILD_DIR/tmp/.build
}

update_feeds() {
    # 删除注释行
    sed -i '/^#/d' "$BUILD_DIR/$FEEDS_CONF"

    # 检查并添加 small-package 源
    if ! grep -q "small-package" "$BUILD_DIR/$FEEDS_CONF"; then
        # 确保文件以换行符结尾
        [ -z "$(tail -c 1 "$BUILD_DIR/$FEEDS_CONF")" ] || echo "" >>"$BUILD_DIR/$FEEDS_CONF"
        echo "src-git small8 https://github.com/kenzok8/small-package" >>"$BUILD_DIR/$FEEDS_CONF"
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

    if [[ -d ./package/istore ]]; then
        \rm -rf ./package/istore
    fi

    if grep -q "nss_packages" "$BUILD_DIR/$FEEDS_CONF"; then
        local nss_packages_dirs=(
            "$BUILD_DIR/feeds/luci/protocols/luci-proto-quectel"
            "$BUILD_DIR/feeds/packages/net/quectel-cm"
            "$BUILD_DIR/feeds/packages/kernel/quectel-qmi-wwan"
        )
        for dir in "${nss_packages_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                \rm -rf "$dir"
            fi
        done
    fi

    # 临时放一下，清理脚本
    if [ -d "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults" ]; then
        find "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults/" -type f -name "99*.sh" -exec rm -f {} +
    fi
}

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        \rm -rf ./feeds/packages/lang/golang
        git clone --depth 1 $GOLANG_REPO -b $GOLANG_BRANCH ./feeds/packages/lang/golang
    fi
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
                install_fullconenat
            else
                ./scripts/feeds install -f -ap $(basename "$dir")
            fi
        fi
    done
}

fix_default_set() {
    # 修改默认主题
    if [ -d "$BUILD_DIR/feeds/luci/collections/" ]; then
        find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    if [ -d "$BUILD_DIR/feeds/small8/luci-theme-argon" ]; then
        find "$BUILD_DIR/feeds/small8/luci-theme-argon" -type f -name "cascade*" -exec sed -i 's/--bar-bg/--primary/g' {} \;
    fi

    install -Dm755 "$BASE_PATH/patches/99_set_argon_primary" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/99_set_argon_primary"

    if [ -f "$BUILD_DIR/package/emortal/autocore/files/tempinfo" ]; then
        if [ -f "$BASE_PATH/patches/tempinfo" ]; then
            \cp -f "$BASE_PATH/patches/tempinfo" "$BUILD_DIR/package/emortal/autocore/files/tempinfo"
        fi
    fi
}

add_wifi_default_set() {
    local qualcommax_uci_dir="$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults"
    local filogic_uci_dir="$BUILD_DIR/target/linux/mediatek/filogic/base-files/etc/uci-defaults"
    if [ -d "$qualcommax_uci_dir" ]; then
        install -Dm755 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$qualcommax_uci_dir/992_set-wifi-uci.sh"
    fi
    if [ -d "$filogic_uci_dir" ]; then
        install -Dm755 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$filogic_uci_dir/992_set-wifi-uci.sh"
    fi
}

update_default_lan_addr() {
    if [[ $BUILD_SRC == *"lede"* ]]; then
        local CFG_PATH="$BUILD_DIR/package/base-files/luci2/bin/config_generate"
    else
        local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
    fi

    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
    fi
}

remove_something_nss_kmod() {
    local ipq_target_path="$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk"
    local ipq_mk_path="$BUILD_DIR/target/linux/qualcommax/Makefile"
    if [ -f $ipq_target_path ]; then
        sed -i 's/kmod-qca-nss-drv-eogremgr//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-gre//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-map-t//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-match//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-mirror//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-pvxlanmgr//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-tun6rd//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-tunipip6//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-drv-vxlanmgr//g' $ipq_target_path
        sed -i 's/kmod-qca-nss-macsec//g' $ipq_target_path
    fi

    if [ -f $ipq_mk_path ]; then
        sed -i 's/kmod-qca-nss-crypto //g' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-eogremgr/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-gre/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-map-t/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-match/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-mirror/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-tun6rd/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-tunipip6/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-vxlanmgr/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-drv-wifi-meshmgr/d' $ipq_mk_path
        sed -i '/kmod-qca-nss-macsec/d' $ipq_mk_path

        sed -i 's/cpufreq //g' $ipq_mk_path
    fi
}

chanage_cpuusage() {
    local luci_dir="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local imm_script1="$BUILD_DIR/package/base-files/files/sbin/cpuusage"

    if [ -f $luci_dir ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" $luci_dir
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' $luci_dir
    fi

    if [ -f "$imm_script1" ]; then
        rm -f "$imm_script1"
    fi

    install -Dm755 "$BASE_PATH/patches/cpuusage" "$BUILD_DIR/target/linux/qualcommax/base-files/sbin/cpuusage"
    install -Dm755 "$BASE_PATH/patches/hnatusage" "$BUILD_DIR/target/linux/mediatek/filogic/base-files/sbin/cpuusage"
}

update_menu_location() {
    local samba4_path="$BUILD_DIR/feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/luci-app-samba4.json"
    if [ -d "$(dirname "$samba4_path")" ] && [ -f "$samba4_path" ]; then
        sed -i 's/nas/services/g' "$samba4_path"
    fi

    local tailscale_path="$BUILD_DIR/feeds/small8/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale.json"
    if [ -d "$(dirname "$tailscale_path")" ] && [ -f "$tailscale_path" ]; then
        sed -i 's/services/vpn/g' "$tailscale_path"
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

function optimize_smartDNS() {
    local smartdns_custom="$BUILD_DIR/feeds/small8/smartdns/conf/custom.conf"
    local smartdns_patch="$BUILD_DIR/feeds/small8/smartdns/patches/010_change_start_order.patch"
    install -Dm644 "$BASE_PATH/patches/010_change_start_order.patch" "$smartdns_patch"

    # 检查配置文件所在的目录和文件是否存在
    if [ -d "${smartdns_custom%/*}" ] && [ -f "$smartdns_custom" ]; then
        # 优化配置选项：
        # serve-expired-ttl: 缓存有效期(单位：小时)，默认值影响DNS解析速度
        # serve-expired-reply-ttl: 过期回复TTL
        # max-reply-ip-num: 最大IP数
        # dualstack-ip-selection-threshold: IPv6优先的阈值
        # server: 配置上游DNS
        echo "优化SmartDNS配置"
        cat >"$smartdns_custom" <<'EOF'
serve-expired-ttl 7200
serve-expired-reply-ttl 5
max-reply-ip-num 3
dualstack-ip-selection-threshold 15
server 223.5.5.5 -bootstrap-dns
EOF
    fi
}

update_mosdns_deconfig() {
    local mosdns_conf="$BUILD_DIR/feeds/small8/luci-app-mosdns/root/etc/config/mosdns"
    if [ -d "${mosdns_conf%/*}" ] && [ -f "$mosdns_conf" ]; then
        sed -i 's/8000/300/g' "$mosdns_conf"
        sed -i 's/5335/5336/g' "$mosdns_conf"
    fi
}

fix_quickstart() {
    local qs_index_path="$BUILD_DIR/feeds/small8/luci-app-quickstart/htdocs/luci-static/quickstart/index.js"
    local fix_path="$BASE_PATH/patches/quickstart_index.js"
    if [ -f "$qs_index_path" ] && [ -f "$fix_path" ]; then
        cat "$fix_path" >"$qs_index_path"
    else
        echo "Quickstart index.js 或补丁文件不存在，请检查路径是否正确。"
    fi
}

update_oaf_deconfig() {
    local conf_path="$BUILD_DIR/feeds/small8/open-app-filter/files/appfilter.config"
    local uci_def="$BUILD_DIR/feeds/small8/luci-app-oaf/root/etc/uci-defaults/94_feature_3.0"
    local disable_path="$BUILD_DIR/feeds/small8/luci-app-oaf/root/etc/uci-defaults/99_disable_oaf"

    if [ -d "${conf_path%/*}" ] && [ -f "$conf_path" ]; then
        sed -i \
            -e "s/record_enable '1'/record_enable '0'/g" \
            -e "s/disable_hnat '1'/disable_hnat '0'/g" \
            -e "s/auto_load_engine '1'/auto_load_engine '0'/g" \
            "$conf_path"
    fi

    if [ -d "${uci_def%/*}" ] && [ -f "$uci_def" ]; then
        sed -i '/\(disable_hnat\|auto_load_engine\)/d' "$uci_def"

        # 禁用脚本
        cat >"$disable_path" <<-EOF
#!/bin/sh
[ "\$(uci get appfilter.global.enable 2>/dev/null)" = "0" ] && {
    /etc/init.d/appfilter disable
    /etc/init.d/appfilter stop
}
EOF
        chmod +x "$disable_path"
    fi
}

support_fw4_adg() {
    local src_path="$BASE_PATH/patches/AdGuardHome"
    local dst_path="$BUILD_DIR/package/feeds/small8/luci-app-adguardhome/root/etc/init.d/AdGuardHome"
    # 验证源路径是否文件存在且是文件，目标路径目录存在且脚本路径合法
    if [ -f "$src_path" ] && [ -d "${dst_path%/*}" ] && [ -f "$dst_path" ]; then
        # 使用 install 命令替代 cp 以确保权限和备份处理
        install -Dm 755 "$src_path" "$dst_path"
        echo "已更新AdGuardHome启动脚本"
    fi
}

add_timecontrol() {
    local timecontrol_dir="$BUILD_DIR/package/luci-app-timecontrol"
    # 删除旧的目录（如果存在）
    rm -rf "$timecontrol_dir" 2>/dev/null
    git clone --depth 1 https://github.com/sirpdboy/luci-app-timecontrol.git "$timecontrol_dir"
}

add_gecoosac() {
    local gecoosac_dir="$BUILD_DIR/package/openwrt-gecoosac"
    # 删除旧的目录（如果存在）
    rm -rf "$gecoosac_dir" 2>/dev/null
    git clone --depth 1 https://github.com/lwb1978/openwrt-gecoosac.git "$gecoosac_dir"
}

update_proxy_app_menu_location() {
    # passwall
    local passwall_path="$BUILD_DIR/package/feeds/small8/luci-app-passwall/luasrc/controller/passwall.lua"
    if [ -d "${passwall_path%/*}" ] && [ -f "$passwall_path" ]; then
        local pos=$(grep -n "entry" "$passwall_path" | head -n 1 | awk -F ":" '{print $1}')
        if [ -n $pos ]; then
            sed -i ''${pos}'i\	entry({"admin", "proxy"}, firstchild(), "Proxy", 30).dependent = false' "$passwall_path"
            sed -i 's/"services"/"proxy"/g' "$passwall_path"
        fi
    fi

    # homeproxy
    local homeproxy_path="$BUILD_DIR/package/feeds/small8/luci-app-homeproxy/root/usr/share/luci/menu.d/luci-app-homeproxy.json"
    if [ -d "${homeproxy_path%/*}" ] && [ -f "$homeproxy_path" ]; then
        sed -i 's/\/services\//\/proxy\//g' "$homeproxy_path"
    fi

    # nikki
    local nikki_path="$BUILD_DIR/package/feeds/small8/luci-app-nikki/root/usr/share/luci/menu.d/luci-app-nikki.json"
    if [ -d "${nikki_path%/*}" ] && [ -f "$nikki_path" ]; then
        sed -i 's/\/services\//\/proxy\//g' "$nikki_path"
    fi
}

update_dns_app_menu_location() {
    # smartdns
    local smartdns_path="$BUILD_DIR/package/feeds/small8/luci-app-smartdns/luasrc/controller/smartdns.lua"
    if [ -d "${smartdns_path%/*}" ] && [ -f "$smartdns_path" ]; then
        local pos=$(grep -n "entry" "$smartdns_path" | head -n 1 | awk -F ":" '{print $1}')
        if [ -n $pos ]; then
            sed -i ''${pos}'i\	entry({"admin", "dns"}, firstchild(), "DNS", 29).dependent = false' "$smartdns_path"
            sed -i 's/"services"/"dns"/g' "$smartdns_path"
        fi
    fi

    # mosdns
    local mosdns_path="$BUILD_DIR/package/feeds/small8/luci-app-mosdns/root/usr/share/luci/menu.d/luci-app-mosdns.json"
    if [ -d "${mosdns_path%/*}" ] && [ -f "$mosdns_path" ]; then
        sed -i 's/\/services\//\/dns\//g' "$mosdns_path"
    fi

    # AdGuardHome
    local adg_path="$BUILD_DIR/package/feeds/small8/luci-app-adguardhome/luasrc/controller/AdGuardHome.lua"
    if [ -d "${adg_path%/*}" ] && [ -f "$adg_path" ]; then
        sed -i 's/"services"/"dns"/g' "$adg_path"
    fi
}

lede() {

    cd $BUILD_DIR
    chmod +x $BASE_PATH/patches/*.sh
    # AdguardHome
    $BASE_PATH/patches/preset-adguardhome.sh $BUILD_DIR
    # lede系统一些特定优化
    $BASE_PATH/patches/lede.sh
    # 添加init-settings
    mkdir -p files/etc/uci-defaults
    cp $BASE_PATH/patches/init-settings.sh files/etc/uci-defaults/99-init-settings

}

main() {
    clean_up
    reset_feeds_conf
    update_feeds
    remove_unwanted_packages
    update_homeproxy
    fix_default_set
    fix_miniupmpd
    update_golang
    change_dnsmasq2full
    fix_mk_def_depends
    add_wifi_default_set
    update_default_lan_addr
    remove_something_nss_kmod
    update_affinity_script
    fix_build_for_openssl
    update_ath11k_fw
    # fix_mkpkg_format_invalid
    chanage_cpuusage
    update_tcping
    add_ax6600_led
    set_custom_task
    update_pw
    install_opkg_distfeeds
    update_nss_pbuf_performance
    set_build_signature
    fix_compile_vlmcsd
    update_nss_diag
    update_menu_location
    fix_compile_coremark
    update_dnsmasq_conf
    add_backup_info_to_sysupgrade
    optimize_smartDNS
    update_mosdns_deconfig
    fix_quickstart
    update_oaf_deconfig
    add_timecontrol
    # add_gecoosac
    install_feeds
    support_fw4_adg
    update_script_priority
    # update_proxy_app_menu_location
    # update_dns_app_menu_location
    if [[ $BUILD_SRC == *"lede"* ]]; then
        lede
    fi
}

main "$@"