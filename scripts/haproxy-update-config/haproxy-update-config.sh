#!/bin/bash
date=$(date "+%d%m%Y_%H%M%S")
user='your-username'
home="/home/$user"
web_service='haproxy'
syscfghapr='/etc/haproxy/haproxy.cfg'
cfghaproxy="$home/haproxy/haproxy.cfg"
loghaproxy="$home/haproxy/logs/haproxy.log"
bkphaproxy="$home/haproxy/bkp/haproxy_${date}.cfg.old"

echo "Checking $web_service configuration file and logging the result in $loghaproxy"
rm -f $loghaproxy
$web_service -c -V -f $cfghaproxy &> $loghaproxy

if grep -Fxq "Configuration file is valid" $loghaproxy; then
	echo "Configuration file is valid, backing up the old $web_service configuration and transferring the new one to the working dir..."
	mv $syscfghapr $bkphaproxy
	cp $cfghaproxy $syscfghapr
	echo "Restarting $web_service"
	service $web_service restart
else
	echo "New configuration file has error(s), please check the file $loghaproxy"
fi
