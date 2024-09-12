#!/bin/bash
echo "execute hotfix.sh"
# https://github.com/coolsnowwolf/lede/commits/master/include/kernel-5.15
# git reset --hard 330337a64451fe229acdcaaab094677c627fb947 
# 修改内核5.10
# sed -i 's/KERNEL_PATCHVER:=*.*/KERNEL_PATCHVER:=6.6/g' target/linux/rockchip/Makefile
# sed -i 's/KERNEL_TESTING_PATCHVER:=*.*/KERNEL_TESTING_PATCHVER:=5.10/g' target/linux/rockchip/Makefile

# 修复rockchip build error
sed -i '/^UBOOT_TARGETS := rk3528-evb rk3588-evb/s/^/#/' package/boot/uboot-rk35xx/Makefile
# fix uqmi build error
sed -i 's/PKG_SOURCE_DATE:=2022-05-04/PKG_SOURCE_DATE:=2024-08-25/g' package/network/utils/uqmi/Makefile
sed -i 's/PKG_SOURCE_VERSION:=56cb2d4056fef132ccf78dfb6f3074ae5d109992/PKG_SOURCE_VERSION:=28b48a10dbcd1177095b73c6d8086d10114f49b8/g' package/network/utils/uqmi/Makefile
sed -i 's/PKG_MIRROR_HASH:=cc832b5318805df8c8387a3650f250dee72d5f1dbda4e4866b5503e186b2210c/PKG_MIRROR_HASH:=ca4c07775185b873da572d973b9bbce86198d41d921a8d32b990da34e5ffd65d/g' package/network/utils/uqmi/Makefile