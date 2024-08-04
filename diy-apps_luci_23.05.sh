#!/bin/bash
##  ======该脚本主要是拉取Apps============
# 移除要替换的包
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-serverchan
# 移除不需要的包
rm -rf feeds/luci/applications/luci-app-vlmcsd # 上网时间控制
rm -rf feeds/luci/applications/luci-app-accesscontrol # DDNS
rm -rf feeds/luci/applications/luci-app-ddns # UPNP
rm -rf feeds/luci/applications/luci-app-upnp # 网络唤醒
rm -rf feeds/luci/applications/luci-app-wol # uu加速器
rm -rf feeds/packages/net/uugamebooster # remove v2ray-geodata package from feeds (openwrt-22.03 & master)
rm -rf feeds/packages/net/v2ray-geodata

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 添加额外插件
git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
git_sparse_clone openwrt-23.05 https://github.com/immortalwrt/luci applications/luci-app-eqos
git_sparse_clone main https://github.com/kenzok8/small-package luci-app-syncthing  uugamebooster

# 科学上网插件
# passwall passwall2 xray v2raya mosdns bypass
git clone --depth=1 -b master https://github.com/kenzok8/small package/luci-app-passwall
# v2raya 
git clone --depth=1 -b master https://github.com/zxlhhyccc/luci-app-v2raya package/luci-app-v2raya
# xray
mkdir -p files/usr/share/xray
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat  -O files/usr/share/xray/geoip.dat
wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/usr/share/xray/geosite.dat

# SmartDNS
git clone --depth=1 -b master https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# Themes
git clone --depth=1 -b master https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 -b master https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# execute diy-script.sh