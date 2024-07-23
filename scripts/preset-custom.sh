#!/bin/bash

# smart相关配置
# 设置smartdns
sed -i "s/option\ port\ '53'/option\ port\ '1753'/g" /etc/config/smartdns
sed -i "s/option\ enabled\ '0'/option\ enabled\ '1'/g" /etc/config/smartdns
# 设置dnsmasq
# sed -i "/^config dnsmasq/a\ \tlist server '127.0.0.1#1753' # SmartDNS的监听端口" /etc/config/dhcp
/etc/init.d/smartdns start 
/etc/init.d/smartdns enable