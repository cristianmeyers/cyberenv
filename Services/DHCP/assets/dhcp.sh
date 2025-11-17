#!/bin/bash

function color() {
    local text="$1"
    local color_code="$2"
    echo -e "\e[${color_code}m${text}\e[0m"
}

function validator() {
    local mensaje="$1"
    if [ $? -ne 0 ]; then
        color "ERREUR : $mensaje" 31
        exit 1
    fi
}

if [ $# -ne 1 ]; then
    echo "Utilisation : sudo $0 <interface>"
    echo "Exemple : sudo $0 enp0s3"
    exit 1
fi

if ! ip addr show "$1" > /dev/null 2>&1; then
    echo "[ $(color "Erreur" 31) ] : L'interface réseau '$(color "$1" 33)' n'existe pas."
    exit 1
else
    IFACE="$1"
    sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      addresses: [192.168.10.2/24]
      nameservers:
        addresses: [192.168.10.2, 1.1.1.1]
EOF
    sudo chown root:root /etc/netplan/01-netcfg.yaml
    sudo chmod 644 /etc/netplan/01-netcfg.yaml
    sudo netplan apply >/dev/null 2>&1
    validator "échec de la configuration de l'interface réseau."
    sudo ip link set enp0s3 up
fi

# Génération temporaire du fichier dhcpd.conf
sudo tee << 'EOF' > /tmp/dhcpd.conf.tmp
# =============================================
# ISC-DHCP-SERVER – 6 VLANs SIO.LAN (2025)
# =============================================
default-lease-time 86400;
max-lease-time 172800;
authoritative;

option domain-name "sio.lan";
option domain-name-servers 192.168.10.1;

# Baux statiques (exemple)
# group "Serveurs" {
#     host siodhcp  { hardware ethernet 08:00:27:c3:fa:15; fixed-address 192.168.10.2; }
#     host siodns   { hardware ethernet 08:00:27:bc:fa:ad; fixed-address 192.168.10.3; }
#     host siotftp  { hardware ethernet 08:00:27:5e:e5:68; fixed-address 192.168.10.4; }
#     host siopsi   { hardware ethernet 08:00:27:f9:c0:65; fixed-address 192.168.10.5; }
# }

# =============================================
# VLAN 10 – 192.168.10.0/24
# =============================================
subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.200;
    option routers 192.168.10.1;
    option broadcast-address 192.168.10.255;
}

# =============================================
# VLAN 20 – 192.168.20.0/24
# =============================================
subnet 192.168.20.0 netmask 255.255.255.0 {
    range 192.168.20.100 192.168.20.200;
    option routers 192.168.20.1;
    option broadcast-address 192.168.20.255;
}

# =============================================
# VLAN 30 – 192.168.30.0/24
# =============================================
subnet 192.168.30.0 netmask 255.255.255.0 {
    range 192.168.30.100 192.168.30.200;
    option routers 192.168.30.1;
    option broadcast-address 192.168.30.255;
}

# VLAN 40
subnet 192.168.40.0 netmask 255.255.255.0 {
    range 192.168.40.100 192.168.40.200;
    option routers 192.168.40.1;
}

# VLAN 50
subnet 192.168.50.0 netmask 255.255.255.0 {
    range 192.168.50.100 192.168.50.200;
    option routers 192.168.50.1;
}

# VLAN 60
subnet 192.168.60.0 netmask 255.255.255.0 {
    range 192.168.60.100 192.168.60.200;
    option routers 192.168.60.1;
}
EOF

validator "impossible de créer le fichier temporaire dhcpd.conf.tmp."

# Installation du serveur DHCP si nécessaire
if ! dpkg -l | grep -q isc-dhcp-server; then
    echo "Installation de isc-dhcp-server..."
    sudo apt update -yq > /dev/null && apt install -y isc-dhcp-server > /dev/null
    validator "échec de l'installation de isc-dhcp-server."
fi

# Copie du fichier dans /etc/dhcp/
sudo cp /tmp/dhcpd.conf.tmp /etc/dhcp/dhcpd.conf
sudo chown root:root /etc/dhcp/dhcpd.conf
sudo chmod 644 /etc/dhcp/dhcpd.conf
validator "échec de la copie du fichier dhcpd.conf."

# Configuration de l’interface
echo "INTERFACESv4=\"$IFACE\"" | sudo tee /etc/default/isc-dhcp-server > /dev/null
validator "échec de la configuration de l'interface DHCP."

# Redémarrage du service
sudo systemctl restart isc-dhcp-server
sleep 2
sudo systemctl status isc-dhcp-server --no-pager

echo "$(color "Fichier" 32) : /etc/dhcp/dhcpd.conf"
