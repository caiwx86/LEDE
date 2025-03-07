#!/bin/bash
echo "execute diy-script.sh"
# hotfix
bash $GITHUB_WORKSPACE/hotfix.sh

# 修改默认IP
sed -i 's/192.168.1.1/10.0.10.1/g' package/base-files/files/bin/config_generate

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

# 更改 Argon 主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

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

git pull
./scripts/feeds update -a
./scripts/feeds install -a
