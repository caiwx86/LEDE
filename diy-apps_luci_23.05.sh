#!/bin/bash
echo "execute diy-apps_luci_23.05.sh"
##  ======该脚本主要是拉取Apps============
# 移除不需要的包
rm -rf feeds/luci/themes/{luci-theme-argon,luci-theme-netgear}
rm -rf feeds/packages/net/{mosdns,smartdns,v2ray-geodata}
rm -rf feeds/luci/applications/{luci-app-vlmcsd,luci-app-accesscontrol,luci-app-ddns,luci-app-wol,luci-app-kodexplorer}
rm -rf feeds/luci/applications/{luci-app-smartdns,luci-app-v2raya,luci-app-mosdns,luci-app-serverchan}

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
  luci-theme-argon luci-app-argon-config \
  smartdns luci-app-smartdns \
  luci-app-npc luci-app-syncthing
#  luci-app-dockerman \
#  luci-app-turboacc
#  luci-app-adguardhome \
#  luci-app-homeassistant luci-lib-taskd taskd luci-lib-xterm
#   luci-app-homebridge

# 科学上网插件
# passwall passwall2 xray v2raya mosdns
git_sparse_clone main https://github.com/caiwx86/openwrt-packages small

# adguardhome
bash $GITHUB_WORKSPACE/scripts/preset-adguardhome.sh
