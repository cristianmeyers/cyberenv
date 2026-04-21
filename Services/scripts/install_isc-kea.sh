#!/bin/bash

# ==========================================================
# SCRIPT D'INSTALLATION AUTOMATIQUE SIODHCP - PROJET CYBER
# Hostname : siodhcp | IP : 192.168.10.2 | DNS AD : 192.168.10.4
# ==========================================================

# 1. Variables de configuration
INTERFACE="ens18" # Vérifie avec 'ip a'
IP_DHCP="192.168.10.2/24"
GATEWAY="192.168.10.1"
DNS_AD="192.168.10.4"
DOMAIN="sio.lan"
PASS="sioPBA29200"

echo "Démarrage de la configuration de siodhcp..."

# 2. Configuration du Hostname
hostnamectl set-hostname siodhcp

# 3. Configuration Réseau (Netplan)
echo "Configuration de l'IP statique (192.168.10.2)..."
cat <<EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $IP_DHCP
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_AD, 8.8.8.8]
        search: [$DOMAIN]
EOF
netplan apply

# 4. Installation de Kea (Mode non-interactif pour éviter l'écran bleu)
echo "Installation de Kea DHCP4 et Control Agent..."
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y kea-dhcp4-server kea-ctrl-agent

# 5. Configuration de l'Agent de Contrôle (API)
echo "Sécurisation de l'API Kea..."
cat <<EOF > /etc/kea/kea-ctrl-agent.conf
{
"Control-agent": {
    "http-host": "127.0.0.1",
    "http-port": 8000,
    "authentication": {
        "type": "basic",
        "clients": [
            {
                "user": "kea-api",
                "password": "$PASS"
            }
        ]
    },
    "control-sockets": {
        "dhcp4": {
            "socket-type": "unix",
            "socket-name": "/run/kea/kea-dhcp4-ctrl.sock"
        }
    }
}
}
EOF

# 6. Configuration du Serveur DHCPv4
echo "Configuration du pool d'adresses et des options AD..."
cat <<EOF > /etc/kea/kea-dhcp4.conf
{
"Dhcp4": {
    "interfaces-config": {
        "interfaces": [ "$INTERFACE" ]
    },
    "control-socket": {
        "socket-type": "unix",
        "socket-name": "/run/kea/kea-dhcp4-ctrl.sock"
    },
    "lease-database": {
        "type": "memfile",
        "persist": true,
        "name": "/var/lib/kea/kea-leases4.csv",
        "lfc-interval": 3600
    },
    "subnet4": [
        {
            "id": 1,
            "subnet": "192.168.10.0/24",
            "pools": [ { "pool": "192.168.10.50 - 192.168.10.150" } ],
            "option-data": [
                { "name": "routers", "data": "$GATEWAY" },
                { "name": "domain-name-servers", "data": "$DNS_AD" },
                { "name": "domain-name", "data": "$DOMAIN" }
            ]
        }
    ],
    "loggers": [
        {
            "name": "kea-dhcp4",
            "output_options": [ { "output": "/var/log/kea-dhcp4.log" } ],
            "severity": "INFO"
        }
    ]
}
}
EOF

# 7. Initialisation des logs et redémarrage des services
touch /var/log/kea-dhcp4.log
chown kea:kea /var/log/kea-dhcp4.log
systemctl restart kea-ctrl-agent kea-dhcp4-server
systemctl enable kea-ctrl-agent kea-dhcp4-server

echo "------------------------------------------------"
echo "Serveur siodhcp configuré avec succès !"
echo "IP : 192.168.10.2 | Gateway : 192.168.10.1"
echo "DNS (AD) : 192.168.10.4"
echo "------------------------------------------------"