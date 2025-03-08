#!/bin/bash
echo "execute hotfix.sh"
# 临时调整文件
# https://github.com/coolsnowwolf/lede/commits/master/include/kernel-5.15
# git reset --hard 330337a64451fe229acdcaaab094677c627fb947 
# 修改内核5.10
sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.6/g' target/linux/rockchip/Makefile
# sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=5.10/g' target/linux/x86/Makefile
# rm -rf feeds/packages/lang/php7
# sed -i 's/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=5.10/g' target/linux/rockchip/Makefile

# 修复rockchip build error
# sed -i '/^UBOOT_TARGETS := rk3528-evb rk3588-evb/s/^/#/' package/boot/uboot-rk35xx/Makefile

# 调整 Docker 到 服务 菜单
# sed -i 's/"admin"/"dmin", "services"/g' feeds/luci/applications/luci-app-dockerman/luasrc/controller/*.lua
# sed -i 's/"admin"/"admin", "services"/g; s/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/model/cbi/dockerman/*.lua
# sed -i 's/admin\//admin\/services\//g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/*.htm
# sed -i 's|admin\\|admin\\/services\\|g' feeds/luci/applications/luci-app-dockerman/luasrc/view/dockerman/container.htm

# luci23.05
# 调整 ttyd 到 系统 菜单
sed -i 's/admin\/services/admin\/system/g' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/*.json
# 调整 带宽监控 到 网络 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-nlbwmon/root/usr/share/luci/menu.d/*.json
# 调整 网络共享 到 NAS 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-samba4/root/usr/share/luci/menu.d/*.json
# 调整 UPNP 到 网络 菜单
sed -i 's/admin\/services/admin\/network/g' feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/*.json
# 调整 Wireguard 到 网络 菜单 
sed -i 's/admin\/status/admin\/network/g' feeds/protocols/luci-proto-wireguard/root/usr/share/luci/menu.d/*.json