#!/bin/bash

color() { echo -e "\e[${2}m${1}\e[0m"; }
validator() { [ $? -eq 0 ] || { color "ERREUR : $1" 31; exit 1; }; }

[ "$EUID" -eq 0 ] || { color "Exécuter avec sudo" 31; exit 1; }

DOMAIN="sio.lan"
KEYNAME="ddns-key-sio"
KEYFILE_BIND="/etc/bind/ddns.key"
KEYFILE_DHCP="/etc/dhcp/ddns.key"
DHCP_CONF="/etc/dhcp/dhcpd.conf"
NAMED_CONF="/etc/bind/named.conf"
BIND_LOCAL="/etc/bind/named.conf.local"
ZONE_DIR="/etc/bind/zones"

clear
color "[ INFO ] : Configuration finale DDNS ISC-DHCP ↔ BIND9" 34

# ------------------------------------------------------------------
# 1. Générer la clé TSIG (une seule fois)
# ------------------------------------------------------------------
if [ ! -f "$KEYFILE_BIND" ]; then
    color "[ INFO ] : Génération de la clé TSIG..." 33
    tsig-keygen -a hmac-sha256 "$KEYNAME" > "$KEYFILE_BIND" 2>/dev/null
    validator "Échec génération clé TSIG"
    chown root:bind "$KEYFILE_BIND"
    chmod 640 "$KEYFILE_BIND"
    color "[ OK ] : Clé TSIG générée → $KEYFILE_BIND" 32
else
    color "[ INFO ] : Clé TSIG déjà existante" 33
fi

# Extraire le secret
DDNS_KEY=$(awk -F '"' '/secret/ {print $2}' "$KEYFILE_BIND")
[ -n "$DDNS_KEY" ] || { color "ERREUR : Impossible d'extraire la clé secrète" 31; exit 1; }

# Copier la clé vers DHCP (meilleure pratique pour les permissions)
cp "$KEYFILE_BIND" "$KEYFILE_DHCP"
chown root:dhcp "$KEYFILE_DHCP"
chmod 640 "$KEYFILE_DHCP"

# ------------------------------------------------------------------
# 2. Inclure la clé dans named.conf (sans doublon)
# ------------------------------------------------------------------
BIND_KEY_INCLUDE='include "/etc/bind/ddns.key";'
if ! grep -q "^include \"/etc/bind/ddns.key\";" "$NAMED_CONF"; then
    # Ajouter au début, après les commentaires éventuels
    sed -i "1i\\
$BIND_KEY_INCLUDE
" "$NAMED_CONF"
    color "[ OK ] : Inclusion de la clé dans named.conf" 32
fi

# ------------------------------------------------------------------
# 3. Activer allow-update pour toutes les zones
# ------------------------------------------------------------------
# Zone directe
if ! grep -q "allow-update.*$KEYNAME" "$BIND_LOCAL"; then
    sed -i "/zone \"$DOMAIN\"/,/};/ s|};|    allow-update { key \"$KEYNAME\"; };\\
};|" "$BIND_LOCAL"
fi

# Zones inverses
for vlan in 10 20 30 40 50 60; do
    zone_name="$vlan.168.192.in-addr.arpa"
    if ! grep -q "allow-update.*$KEYNAME" "$BIND_LOCAL" || ! grep -q "$zone_name" "$BIND_LOCAL"; then
        sed -i "/zone \"$zone_name\"/,/};/ s|};|    allow-update { key \"$KEYNAME\"; };\\
};|" "$BIND_LOCAL"
    fi
done

# ------------------------------------------------------------------
# 4. Préparer le bloc DDNS pour dhcpd.conf
# ------------------------------------------------------------------
cat > /tmp/ddns-dhcp.conf <<EOF
# =============================================
# DDNS – Mise à jour DNS uniquement pour hosts statiques
# Généré le $(date +%Y-%m-%d)
# =============================================
ddns-update-style interim;
ddns-domainname "$DOMAIN.";
ddns-rev-domainname "in-addr.arpa.";
ignore client-updates;
update-static-leases on;
use-host-decl-names on;

key "$KEYNAME" {
    algorithm hmac-sha256;
    secret "$DDNS_KEY";
}

zone $DOMAIN. {
    primary 192.168.10.2;
    key "$KEYNAME";
}

zone 10.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
zone 20.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
zone 30.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
zone 40.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
zone 50.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
zone 60.168.192.in-addr.arpa. {
    primary 192.168.10.2;
    key "$KEYNAME";
}
EOF

# ------------------------------------------------------------------
# 5. Intégrer le bloc DDNS dans dhcpd.conf (idempotent)
# ------------------------------------------------------------------
if ! grep -q "ddns-update-style interim" "$DHCP_CONF"; then
    # Sauvegarde
    cp "$DHCP_CONF" "${DHCP_CONF}.bak"

    # Supprimer les options DNS redondantes
    sed -i '/option domain-name /d' "$DHCP_CONF"
    sed -i '/option domain-name-servers /d' "$DHCP_CONF"

    # Ajouter les options une seule fois après 'authoritative;'
    sed -i "/^authoritative;/a option domain-name \"$DOMAIN\";\noption domain-name-servers 192.168.10.2;" "$DHCP_CONF"

    # Préfixer le fichier existant avec le bloc DDNS
    cat /tmp/ddns-dhcp.conf "$DHCP_CONF" > /tmp/dhcpd.new
    mv /tmp/dhcpd.new "$DHCP_CONF"
    chown root:root "$DHCP_CONF"
    chmod 644 "$DHCP_CONF"
    color "[ OK ] : Bloc DDNS intégré dans dhcpd.conf" 32
else
    color "[ INFO ] : Configuration DDNS déjà présente" 33
fi

# ------------------------------------------------------------------
# 6. Validation des configurations
# ------------------------------------------------------------------
color "[ INFO ] : Vérification de la configuration BIND9..." 34
named-checkconf >/dev/null 2>&1
validator "Erreur dans named.conf"

color "[ INFO ] : Vérification de la zone directe..." 34
named-checkzone "$DOMAIN" "$ZONE_DIR/db.$DOMAIN" >/dev/null 2>&1
validator "Erreur dans la zone directe"

for vlan in 10 20 30 40 50 60; do
    named-checkzone "$vlan.168.192.in-addr.arpa" "$ZONE_DIR/db.192.168.$vlan" >/dev/null 2>&1
    validator "Erreur dans la zone inverse $vlan"
done

color "[ INFO ] : Vérification de la configuration DHCP..." 34
dhcpd -t -cf "$DHCP_CONF" >/dev/null 2>&1
validator "Erreur dans dhcpd.conf"

# ------------------------------------------------------------------
# 7. Redémarrage des services
# ------------------------------------------------------------------
systemctl restart bind9
validator "Échec du redémarrage de bind9"

systemctl restart isc-dhcp-server
validator "Échec du redémarrage de isc-dhcp-server"

color "[ OK ] : Intégration DDNS réussie !" 32
color " → Seuls les hosts statiques seront enregistrés dans le DNS" 37
color " → Exemple : décommentez un host dans /etc/dhcp/dhcpd.conf pour le voir en DNS" 37

echo
systemctl status bind9 --no-pager -l
echo
systemctl status isc-dhcp-server --no-pager -l