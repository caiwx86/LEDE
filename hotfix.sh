#!/bin/bash
echo "execute hotfix.sh"
# https://github.com/coolsnowwolf/lede/commits/master/include/kernel-5.15
# git reset --hard 330337a64451fe229acdcaaab094677c627fb947 
# 修改内核5.10
sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.6/g' target/linux/rockchip/Makefile
# sed -i 's/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=5.10/g' target/linux/rockchip/Makefile

# ccache
sed -i 's/ccache_cc/ccache/g' rules.mk

# 修复rockchip build error
sed -i '/^UBOOT_TARGETS := rk3528-evb rk3588-evb/s/^/#/' package/boot/uboot-rk35xx/Makefile
