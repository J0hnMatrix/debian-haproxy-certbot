#!/bin/bash
le_path='/etc/letsencrypt/'
cert_path="$le_path/live/"

for i in $( ls -F "$cert_path" | grep / | sed 's/\/$//' ); do
domain=$i

user='your-username'
home="/home/$user"
web_service='haproxy'
exp_limit=15

cert_file="$cert_path/$domain/fullchain.pem"
key_file="$cert_path/$domain/privkey.pem"
dom_path="$cert_path/$domain"
config_file="$le_path/renewal/${domain}.conf"
combined_file="/etc/haproxy/certs/${domain}.pem"

exp=$(date -d "`openssl x509 -in $cert_file -text -noout | grep "Not After" | cut -c 25-`" +%s)
datenow=$(date -d "now" +%s)
days_exp=$(echo \( $exp - $datenow \) / 86400 | bc)


echo "=============HAProxy and Certbot renewal script============="
echo $(date "+%d-%m-%Y %H:%M:%S")

echo "Performing renewal for domain: $domain"
echo 'Checking prerequisites...'

if [ ! -f $config_file ]; then
        echo "[ERROR] config file does not exist: $config_file"
	elif [ ! -f $cert_file ]; then
		echo "[ERROR] certificate file not found for domain $domain."
	else
		echo "Checking expiration date for $domain..."
			if [ "$days_exp" -gt "$exp_limit" ]; then
				echo "The certificate is up to date, no need for renewal ($days_exp days left - target min $exp_limit days)."
			else
				echo "The certificate for $domain is about to expire soon. Starting Let's Encrypt renewal command..."
				# certbot renew --dry-run
				certbot renew

				echo "Creating $combined_file with latest certs..."
				cat $cert_file $key_file > $combined_file
			
				echo "Renewal process finished for domain $domain"
				
				echo "Cleaning and copying certificate files in $home/certbot"
				rm -Rf $home/certbot
				cp -LR $cert_path $home/certbot
			
				echo "Changing permissions and ownership for $domain certificates"
				chmod -R 770 $home/certbot
				chgrp -R $user $home/certbot
				chown -R $user $home/certbot
				
				echo "Restarting $web_service"
				service $web_service restart
			fi
fi

done

echo $(date "+%d-%m-%Y %H:%M:%S")
echo "=============End of script============="
