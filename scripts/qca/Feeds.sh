#!/bin/bash

#LEDE平台调整
if [[ $WRT_SUFFIX == "LEDE" ]]; then
	# sed -i '/openwrt-23.05/d' feeds.conf.default
	# sed -i 's/^#\(.*luci\)/\1/' feeds.conf.default
  #  sed -i 's/#src-git helloworld/src-git helloworld/g' ./feeds.conf.default


#  ======该脚本主要是拉取Apps============
# 移除不需要的包
rm -rf feeds/luci/themes/{luci-theme-argon,luci-theme-netgear}
rm -rf feeds/packages/net/{mosdns,smartdns,v2ray-geodata}
rm -rf feeds/luci/applications/{luci-app-vlmcsd,luci-app-accesscontrol,luci-app-ddns,luci-app-wol,luci-app-kodexplorer}
rm -rf feeds/luci/applications/{luci-app-smartdns,luci-app-v2raya,luci-app-mosdns,luci-app-serverchan,luci-app-passwall2}

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
git_sparse_clone small-package  https://github.com/caiwx86/openwrt-packages \
  luci-app-npc luci-app-syncthing
#  luci-app-homeassistant luci-lib-taskd taskd luci-lib-xterm
#   luci-app-homebridge

# 科学上网插件
# passwall2 xray v2raya mosdns luci-app-ssr-plus luci-app-amlogic luci-app-smartdns luci-theme-argon
# git_sparse_clone main https://github.com/caiwx86/openwrt-packages small
git clone --depth=1  https://github.com/kenzok8/openwrt-packages package/kenzok8
git clone --depth=1  https://github.com/kenzok8/small package/small
rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,v2ray*,sing*,smartdns,geoview}
rm -rf feeds/packages/utils/v2dat

# 在线用户
git_sparse_clone main https://github.com/danchexiaoyang/luci-app-onliner luci-app-onliner 
# adguardhome
bash $GITHUB_WORKSPACE/scripts/preset-adguardhome.sh

fi

# DNSMASQ DNSSERVER
sed -i 's/DNS_SERVERS=\"\"/DNS_SERVERS=\"223.5.5.5 8.8.4.4\"/g' package/network/services/dnsmasq/files/dnsmasq.init

./scripts/feeds update -a
./scripts/feeds install -af
