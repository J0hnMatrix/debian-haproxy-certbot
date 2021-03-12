# **HAProxy & Certbot**

Ce tuto a pour but d'installer HAProxy et Certbot sur la même VM Linux et ainsi avoir un Reverse Proxy avec renouvellement automatique des certificats SSL Letsencrypt.

## Prérequis :
 * Avoir déployé une VM Debian
 * Avoir un nom de domaine auprès d'un bureau d'enregistrement compatible avec la fonction DNS01 de Certbot https://certbot.eff.org/docs/using.html#dns-plugins
 * Avoir un mail faisant office de compte technique pour l'envoi de mail (ex: certbot.your.domain.fr@gmail.com)
 * Avoir récupéré le token auprès du bureau d'enregistrement (ici OVH : https://certbot-dns-ovh.readthedocs.io/en/stable/)
 * Avoir un fichier de configuration pour HAProxy.

Pour la partie renouvellement du certificat, une tâche Crontab sera créée pour être exécutée tous les jours à 4h00, le résultat sera sauvegardé dans un fichier log et envoyé par mail.  

Par défaut la commande **certbot renew** ne sera exécutée qu'à 2 jours de l'expiration du certificat (peut être modifié)  

Une fois le renouvellement terminé, le nouveau certificat sera automatiquement mis en place pour HAProxy et ce dernier sera automatiquement relancé.  

Egalement une copie des fichiers du certificat (**cert.pem ; chain.pem ; fullchain.epm ; privkey.pem**) sera copié dans **~/certbot/**

Le rôle d'Incrontab sera de :
 * Valider le fichier de configuration de HAProxy (**~/haproxy/haproxy.cfg**) à chaque fois qu'il sera modifié (condition **IN_CLOSE_WRITE**) et il :
	* Sauvegardera la configuration actuelle dans le répertoire **~/haproxy/bkp**
	* Copiera le nouveau fichier de configuration dans **/etc/haproxy/**
	* Relancera le service **HAProxy**

 * Dans le cas ou il ne sera pas valide, HAProxy ne sera pas relancé et l'utilisateur devra corriger les erreurs (log présent dans **~/haproxy/logs**)


## Variables du tuto :
 * *linux-local-account* doit être remplacée par le compte utilisateur présent sur le serveur 
 * *your.domain.fr* doit être remplacée par votre nom de domaine.


## Mise en place de l'environnement Linux
(Depuis le serveur Linux avec le compte utilisateur)

* Installer bc, incrontab et samba
```console
sudo apt install bc incrontab samba samba-common-bin
```

* Créer le répertoire ~/.secrets/certbot/
```console
mkdir ~/.secrets/certbot/
```

* Créer les shares Samba suivants :
```console
sudo nano /etc/samba/smb.conf
```

* Changer le nom du Workgroup dans la section Global
* A la fin du fichier rajouter :

***
```text
[home-linux-local-account]
comment = Share for home folder
path = /home/linux-local-account
   writeable = yes
   browsable = yes
   public = yes
   create mask = 0644
   directory mask = 0755
   force user = linux-local-account

[certbot-dns-ovh]
comment = Share for the certbot-dns-ovh plugin
path = /home/linux-local-account/.secrets/certbot/
   writeable = yes
   browsable = yes
   public = yes
   create mask = 0600
   directory mask = 0755
   force user = linux-local-account
```
***

* Redémarrer le service Samba:
```console
sudo service smbd restart
```

* Lancer un explorateur de fichiers Windows et se connecter au serveur Linux et vérifier que chaque partage est accessible.

* Créer/Copier/Renommer le fichier **ovh.ini** contenant le token fourni par le bureau d'enregistrement et le copier dans **~/.secrets/certbot/**

* Lui donner des permissions en lecture seule :
```console
chmod 600 ~/.secrets/certbot/ovh.ini
```

* Copier le répertoire **scripts** dans **~/**

* Changer la variable **user** correspondante à votre nom d'utilisateur dans tous les scripts :
```console
find ~/scripts/ -type f -iname "*.sh" -exec sed -i "s/your-username/"$USER"/g" {} \;
```

* Changer l'adresse mail par votre adresse (remplacer **$your-new-mail** dans la commande) :
```console
find ~/scripts/ -type f -iname "*.sh" -exec sed -i 's/your@mail.com/$your-new-mail/g' {} \;
```

* Attribuer les permissions d'exécution sur tous les fichiers .sh :
```console
find ~/scripts/ -type f -iname "*.sh" -exec chmod +x {} \;
```


## Installation et configuration de Certbot

* Installer Certbot via la procédure :
https://certbot.eff.org/instructions#wildcard

* Lancer la génération d'un nouveau certificat avec la commande :
```console
sudo certbot certonly \
  --dns-ovh \
  --dns-ovh-credentials ~/.secrets/certbot/ovh.ini \
  --dns-ovh-propagation-seconds 60 \
  -d your.domain.fr \
  -d *.your.domain.fr
```

## Installation et configuration de HAProxy

* Installer HAProxy via la procédure :
https://haproxy.debian.net/

* Préparer le premier certificat pour HAProxy
```console
sudo cat /etc/letsencrypt/live/your.domain.fr/fullchain.pem /etc/letsencrypt/live/your.domain.fr/privkey.pem > /etc/haproxy/certs/
```

* Créer le répertoire pour HAProxy dans **~/**
```console
mkdir ~/haproxy
```

* Copier le fichier de configuration dans **~/haproxy/** et le renommer en **haproxy.cfg** si nécessaire

* Vérifier la validité du fichier de configuration avec la commande :
```console
sudo haproxy -c -V -f ~/haproxy/haproxy.cfg
```

Il devrait y avoir la ligne **Configuration file is valid** pour indiquer que le fichier de configuration est valide, sinon corriger les erreurs.


## Installation et configuration de MSMTP

* Installer MSMTP pour récupérer le résultat du script via mail
```console
sudo apt install msmtp-mta
```

* Créer un fichier **/etc/msmtprc** selon le modèle suivant

***
```text
# Set default values for all following accounts.
defaults
port 587
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account gmail
host smtp.gmail.com
from <your-technical-mail>@gmail.com
auth on
user <your-technical-mail>
password <the-password-of-your-technical-mail>

# Set a default account
account default : gmail
```
***
  
* Si vous utilisez un compte GMail, il faudra désactiver l'option de sécurité "Accès moins sécurisé des applications" (Google va gueuler)

* Tester avec la commande :
```console
echo -e "Subject: [Your-domain] Certbot renewal status" | msmtp <your-mail>@gmail.com
```

* Avec le compte root, mettre en place un cron qui lancera ce script tous les jours à 4h00 du matin :
```console
sudo crontab -e
```

* Ajouter la ligne :
```text
00 04 * * * /home/linux-local-account/scripts/certbot-haproxy-renew/launch-renew.sh
```

## Configuration d'Incrontab

* Spécifier l'utilisateur root comme étant le seul à pouvoir lancer des tâches Incrontab
```console
echo root | sudo tee -a /etc/incron.allow
```

* Créer la tâche Incrontab
```console
sudo incrontab -e
```
```text
/home/linux-local-account/haproxy/haproxy.cfg	IN_CLOSE_WRITE	/home/linux-local-account/scripts/incron/launch-haproxy-incron.sh
```

* Redémarrer le service Incron
```console
sudo service incron restart
```

## Tester !
