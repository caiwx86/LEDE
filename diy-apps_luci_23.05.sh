#!/bin/bash
echo "execute diy-apps_luci_23.05.sh"
##  ======该脚本主要是拉取Apps============
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
# passwall passwall2 xray v2raya mosdns
# git_sparse_clone main https://github.com/caiwx86/openwrt-packages small
sed -i '1i src-git kenzo https://github.com/kenzok8/openwrt-packages' feeds.conf.default
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default
rm -rf feeds/packages/net/{alist,adguardhome,mosdns,xray*,v2ray*,v2ray*,sing*,smartdns}
rm -rf feeds/packages/utils/v2dat

# 在线用户
git_sparse_clone main https://github.com/danchexiaoyang/luci-app-onliner luci-app-onliner 
# 晶晨宝盒
git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/haiibo/OpenWrt'|g" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|kernel_path.*|kernel_path 'https://github.com/ophub/kernel'|g" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|ARMv8_PLUS|g" package/luci-app-amlogic/root/etc/config/amlogic

# adguardhome
bash $GITHUB_WORKSPACE/scripts/preset-adguardhome.sh
