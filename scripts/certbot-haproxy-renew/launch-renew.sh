#!/bin/bash
timestamp=$(date "+%d%m%Y_%H%M%S")
user='your-username'
home="/home/$user"
mailto='your@mail.com'
scriptloc="$home/scripts/certbot-haproxy-renew"
logfile="$scriptloc/logs/certbot-haproxy-renew_${timestamp}.log"

$scriptloc/certbot-haproxy-renew.sh &> $logfile

if [ ! -f $logfile ]; then
        echo 'Cannot retrieve logfile, aborting...'
        else
                echo "Sending logfile to $mailto"
                cat $logfile | msmtp $mailto
fi

