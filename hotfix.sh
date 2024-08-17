#!/bin/bash

# 修复rockchip build error
sed -i '/^UBOOT_TARGETS := rk3528-evb rk3588-evb/s/^/#/' package/boot/uboot-rk35xx/Makefile