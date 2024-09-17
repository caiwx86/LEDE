#!/bin/bash
echo "execute preset-adguardhome.sh"
#修改luci-app-adguardhome配置config文件
cd $OPENWRT_PATH
mkdir -p files/usr/bin
AGH_CORE=$(curl -sL https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | grep /AdGuardHome_linux_$CLASH_KERNEL | awk -F '"' '{print $4}')
wget -qO- $AGH_CORE | tar xOvz > files/usr/bin/AdGuardHome
chmod +x files/usr/bin/AdGuardHome

cp $GITHUB_WORKSPACE/scripts/adguard_update_dhcp_leases.sh files/usr/bin/adguard_update_dhcp_leases.sh
sed -i "s|option workdir '/etc/AdGuardHome'|option workdir '/opt/AdGuardHome'|" package/luci-app-adguardhome/root/etc/config/AdGuardHome
sed -i "s|option configpath '/etc/AdGuardHome.yaml'|option configpath '/opt/AdGuardHome/AdGuardHome.yaml'|" package/luci-app-adguardhome/root/etc/config/AdGuardHome