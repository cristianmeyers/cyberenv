#!/bin/bash

# ==========================================================
# SCRIPT D'INSTALLATION AUTOMATIQUE SAMBA AD - PROJET CYBER
# Domaine : sio.lan | Hostname : sioad | IP : 192.168.1.10
# ==========================================================

# 1. Variables de configuration
DOMAIN="SIO.LAN"
NETBIOS_NAME="SIO"
HOSTNAME="sioad"
IP_STATIC="192.168.1.10/24"
GATEWAY="192.168.1.1"
INTERFACE="ens18" # À vérifier avec 'ip a'
ADMIN_PASS="sioPBA29200"

echo "Démarrage de l'installation de l'AD pour $DOMAIN..."

# 2. Configuration du Hostname et /etc/hosts
hostnamectl set-hostname $HOSTNAME
sed -i "1i $IP_STATIC $HOSTNAME.$DOMAIN $HOSTNAME" /etc/hosts

# 3. Mise à jour et installation des paquets
# On utilise DEBIAN_FRONTEND=noninteractive pour éviter les questions de Kerberos
apt update
DEBIAN_FRONTEND=noninteractive apt install -y samba krb5-config krb5-user winbind libpam-winbind libnss-winbind python3-setproctitle acl

# 4. Neutralisation des services conflictuels
echo "Nettoyage des services système..."
systemctl stop smbd nmbd winbind systemd-resolved
systemctl disable smbd nmbd winbind systemd-resolved
systemctl mask smbd nmbd winbind

# 5. Configuration DNS temporaire pour le provisioning
rm /etc/resolv.conf
echo "nameserver 127.0.0.1" > /etc/resolv.conf
echo "search $DOMAIN" >> /etc/resolv.conf

# 6. Provisioning du domaine
echo "Provisioning du domaine Samba AD..."
[ -f /etc/samba/smb.conf ] && mv /etc/samba/smb.conf /etc/samba/smb.conf.bak

samba-tool domain provision \
  --use-rfc2307 \
  --realm=$DOMAIN \
  --domain=$NETBIOS_NAME \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --adminpass="$ADMIN_PASS"

# 7. Configuration du Forwarder DNS dans smb.conf
# On ajoute le forwarder 8.8.8.8 pour ne pas perdre internet
sed -i "/\[global\]/a \    dns forwarder = 8.8.8.8" /etc/samba/smb.conf

# 8. Activation du service AD DC
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

# 9. Liaison Kerberos
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

# 10. Test final
echo "------------------------------------------------"
echo "Installation terminée. Test de Kerberos en cours..."
echo "$ADMIN_PASS" | kinit administrator@$DOMAIN
klist

echo "------------------------------------------------"
echo "IMPORTANT : Vérifiez votre fichier Netplan pour fixer l'IP"
echo "et pointez le DNS sur 127.0.0.1 pour finir proprement."