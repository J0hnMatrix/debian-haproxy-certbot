#!/bin/bash
timestamp=$(date "+%d%m%Y_%H%M%S")
user='your-username'
home="/home/$user"
scriptloc="$home/scripts/haproxy-update-config"
logfile="$home/incron/logs/launch-haproxy-incron_${timestamp}.log"

$scriptloc/haproxy-update-config.sh &> $logfile

