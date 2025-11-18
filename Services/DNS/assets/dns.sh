#!/bin/bash

color() { echo -e "\e[${2}m${1}\e[0m"; }
validator() { [ $? -eq 0 ] || { color "ERREUR : $1" 31; exit 1; }; }

[ "$EUID" -eq 0 ] || { color "Exécuter avec sudo" 31; exit 1; }

DNS_IP="192.168.10.2"
DOMAIN="sio.lan"
HOSTNAME="siodhcp"
ZONE_DIR="/etc/bind/zones"
SERIAL=$(date +%Y%m%d)01

sudo apt update -qq 
clear
color "[ INFO ] : Installation de BIND9 en cours..." 34
sudo apt install -y bind9 bind9-utils dnsutils >/dev/null 2>&1
validator "Installation bind9 échouée"
color "[ OK ] : bind9 installé avec succès." 32

color "[ INFO ] : Configuration de BIND9 en cours..." 34
mkdir -p "$ZONE_DIR" /var/cache/bind
chown -R bind:bind "$ZONE_DIR" /var/cache/bind
chmod 775 "$ZONE_DIR" /var/cache/bind
color "[ OK ] : Répertoires de zones créés et permissions définies." 32

cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { none; };
    allow-query { any; };
    recursion yes;
    allow-recursion { none; };
#   allow-recursion { 192.168.10.0/24; localhost; };
#   forwarders {
#      8.8.8.8;
#       8.8.4.4;
#   };
    allow-transfer { none; };
};
EOF

cat > /etc/bind/named.conf.local <<EOF
zone "$DOMAIN" {
    type master;
    file "$ZONE_DIR/db.$DOMAIN";
};

zone "10.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.10"; };
zone "20.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.20"; };
zone "30.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.30"; };
zone "40.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.40"; };
zone "50.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.50"; };
zone "60.168.192.in-addr.arpa" { type master; file "$ZONE_DIR/db.192.168.60"; };
EOF

cat > /etc/bind/named.conf <<EOF
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
EOF

cat > "$ZONE_DIR/db.$DOMAIN" <<EOF
\$TTL 86400
@ IN SOA $HOSTNAME.$DOMAIN. admin.$DOMAIN. ( $SERIAL 3600 1800 604800 86400 )
@ IN NS $HOSTNAME.$DOMAIN.
$HOSTNAME IN A $DNS_IP
EOF
chown root:bind "$ZONE_DIR/db.$DOMAIN" && chmod 664 "$ZONE_DIR/db.$DOMAIN"

for vlan in 10 20 30 40 50 60; do
    cat > "$ZONE_DIR/db.192.168.$vlan" <<EOF
\$TTL 86400
@ IN SOA $HOSTNAME.$DOMAIN. admin.$DOMAIN. ( $SERIAL 3600 1800 604800 86400 )
@ IN NS $HOSTNAME.$DOMAIN.
EOF
    chown root:bind "$ZONE_DIR/db.192.168.$vlan" && chmod 664 "$ZONE_DIR/db.192.168.$vlan"
done

named-checkconf
validator "Erreur dans la configuration de BIND"

named-checkzone $DOMAIN "$ZONE_DIR/db.$DOMAIN" || exit 1
for vlan in 10 20 30 40 50 60; do
    named-checkzone "192.168.$vlan.in-addr.arpa" "$ZONE_DIR/db.192.168.$vlan" || exit 1
done

systemctl restart bind9
validator "Erreur lors du redémarrage de bind9"

sleep 2
systemctl status bind9 --no-pager
