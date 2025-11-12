# DNS (Domain Name System)

Pour le service **DNS**, j'ai choisi un **Ubuntu Live server 24.04 LTS** comme serveur principal avec `Bind9` comme service DNS.
Ici, la configuration part de zéro, mais **tous les enregistrements seront gérés automatiquement par ISC-DHCP via DDNS**, sans toucher manuellement aux fichiers de zones.

---

## Configuration et déploiement DNS

### ÉTAPE 1 : Mise à jour système + installation propre BIND9 (2025)

```bash
# Mise à jour complète du système
sudo apt update && sudo apt upgrade -y

# Installation officielle BIND9 + outils + dig
sudo apt install bind9 bind9-utils bind9-doc bind9-dnsutils -y

# Ubuntu 24.04 utilise named.service (pas bind9.service)
sudo systemctl unmask named.service 2>/dev/null || true
sudo systemctl enable named.service

# Vérification que le service existe
sudo systemctl status named.service
```

> Après cette étape :
>
> - BIND9 est installé proprement
> - Le service s’appelle `named.service`
> - Aucune configuration personnalisée n’est encore faite
> - Le serveur DNS ne répond à rien pour l’instant

**Sortie attendue :**

```
● named.service - BIND Domain Name Server
   Loaded: loaded (/lib/systemd/system/named.service; enabled; preset: enabled)
   Active: inactive (dead)
```

---

### ÉTAPE 2 : Configuration de `named.conf`

C’est le fichier principal de BIND9. Il indique où trouver les autres fichiers de configuration.
Il ne contient aucune règle, juste **3 includes**.

```bash
sudo nano /etc/bind/named.conf
```

**Contenu :**

```bash
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
```

> **RÈGLE D’OR :**
> NE JAMAIS toucher ce fichier après l’installation.
> Si on change quoi que ce soit ici = **DNS mort**.

---

### ÉTAPE 3 : Configuration de `named.conf.options`

C’est le cerveau de BIND9 : où écouter, qui peut interroger, récursion, forwarders…

```bash
sudo nano /etc/bind/named.conf.options
```

**Contenu recommandé pour le lab :**

```bash
options {
    directory "/var/cache/bind";

    # Autorise tout le monde à interroger (lab)
    allow-query { any; };

    # On désactive la récursion pour l’instant
    recursion no;

    # Écoute UNIQUEMENT sur le serveur et localhost
    listen-on port 53 { 127.0.0.1; 192.168.10.2; };
    listen-on-v6 { none; };

    # Sécurité minimale
    dnssec-validation auto;
    auth-nxdomain no;
};
```

> **ATTENTION** : vérifier que l’adresse IP correspond à ton serveur.

---

### ÉTAPE 4 : Configuration de `named.conf.local`

C’est ici que l’on déclare les **zones personnelles**.
Pour un DHCP/DDNS centralisé, les zones restent **minimales**.

```bash
sudo nano /etc/bind/named.conf.local
```

**Exemple complet pour VLAN 10 → 60 :**

```bash
# Clé TSIG pour DDNS
key "DHCP_UPDATE" {
    algorithm hmac-sha256;
    secret "LA_CLE_GENEREE_DANS_RNDC.KEY";  # Remplacer par la vraie clé
};

# Zone directe minimale
zone "sio.lan" {
    type master;
    file "/etc/bind/zones/db.sio.lan";
    allow-update { key DHCP_UPDATE; };
};

# Zones inverses minimales pour chaque VLAN
zone "10.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.10"; allow-update { key DHCP_UPDATE; }; };
zone "20.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.20"; allow-update { key DHCP_UPDATE; }; };
zone "30.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.30"; allow-update { key DHCP_UPDATE; }; };
zone "40.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.40"; allow-update { key DHCP_UPDATE; }; };
zone "50.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.50"; allow-update { key DHCP_UPDATE; }; };
zone "60.168.192.in-addr.arpa" { type master; file "/etc/bind/zones/db.192.168.60"; allow-update { key DHCP_UPDATE; }; };
```

---

### ÉTAPE 5 : Fichiers de zone minimale

#### Zone directe `db.sio.lan`

```bash
sudo tee /etc/bind/zones/db.sio.lan > /dev/null << 'EOF'
$TTL 604800
@   IN  SOA dhcp.sio.lan. admin.sio.lan. (
        2025111201 ; Serial
        604800
        86400
        2419200
        60480 )
@   IN  NS dhcp.sio.lan.
EOF
```

#### Zones inverses VLAN 10 → 60

Exemple pour VLAN 10 (`db.192.168.10`), les autres VLAN suivent le même modèle :

```bash
sudo tee /etc/bind/zones/db.192.168.10 > /dev/null << 'EOF'
$TTL 604800
@   IN  SOA dhcp.sio.lan. admin.sio.lan. (
        2025111201
        604800
        86400
        2419200
        60480 )
@   IN  NS dhcp.sio.lan.
EOF
```

- Dupliquer pour VLAN 20 → 60 en changeant uniquement le nom de fichier.

---

### ÉTAPE 6 : Permissions + Vérification

```bash
sudo chown -R bind:bind /etc/bind/zones
sudo chmod 640 /etc/bind/zones/*
sudo named-checkconf && echo "SYNTAXE 100% OK"
```

---

### ÉTAPE 7 : Démarrage et redémarrage des services

```bash
sudo systemctl restart named
sudo systemctl restart isc-dhcp-server
```

> Tous les hôtes DHCP recevront automatiquement un nom en `*.sio.lan` et leurs PTR seront gérés via DDNS.
> Aucune modification manuelle des fichiers de zone n’est nécessaire.

---

# Résumé

- DNS minimal, juste pour que Bind démarre.
- Toutes les zones (directes et inverses) sont gérées **automatiquement par DHCP/DDNS**.
- Les fichiers de zones sont créés vides ou avec le strict minimum (SOA + NS).
- Le DHCP attribue les IP et met à jour Bind via DDNS.
