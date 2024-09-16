#!/bin/bash
echo "execute preset-adguardhome.sh"
#修改luci-app-adguardhome配置config文件
cd $OPENWRT_PATH
mkdir -p files/usr/bin
cp $GITHUB_WORKSPACE/scripts/adguard_update_dhcp_leases.sh files/usr/bin/adguard_update_dhcp_leases.sh
sed -i "s|option workdir '/etc/AdGuardHome'|option workdir '/opt/AdGuardHome'|" package/luci-app-adguardhome/root/etc/config/AdGuardHome
sed -i "s|option configpath '/etc/AdGuardHome.yaml'|option configpath '/opt/AdGuardHome/AdGuardHome.yaml'|" package/luci-app-adguardhome/root/etc/config/AdGuardHome