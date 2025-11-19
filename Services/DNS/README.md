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

---

# DNS Documentation : Intégration DHCP–BIND avec mises à jour dynamiques (DDNS)

## 1. Objectif

Ce document décrit la procédure complète pour configurer un serveur ISC DHCP et un serveur DNS BIND9 afin de permettre les mises à jour dynamiques sécurisées (DDNS). Le DHCP pourra ainsi ajouter, mettre à jour et supprimer automatiquement les enregistrements DNS directs (A) et inverses (PTR).

La configuration utilise une clé TSIG HMAC‑SHA256 pour sécuriser les échanges entre DHCP et BIND.

---

## 2. Création de la clé TSIG

La clé TSIG est utilisée par le serveur DHCP pour authentifier les mises à jour envoyées à BIND.

### Commande de génération

```bash
tskeygen -a hmac-sha256 dhcp-update-key
```

### Exemple de sortie

```conf
key "dhcp-update-key" {
    algorithm hmac-sha256;
    secret "5z31HPwmqmbSutVXyuOMOYfuh4GgVnzVwmjuHzG3t88=";
};
```

---

## 3. Stockage de la clé dans un fichier séparé

Il est recommandé de ne pas laisser la clé apparaître directement dans les fichiers de configuration.

Créer un dossier dédié :

```bash
sudo mkdir -p /etc/bind/keys
sudo chown bind:bind /etc/bind/keys
sudo chmod 750 /etc/bind/keys
```

Créer le fichier de clé :

```bash
sudo nano /etc/bind/keys/dhcp-update.key
```

Y placer :

```conf
key "dhcp-update-key" {
    algorithm hmac-sha256;
    secret "5z31HPwmqmbSutVXyuOMOYfuh4GgVnzVwmjuHzG3t88=";
};
```

Définir les permissions :

```bash
sudo chown bind:bind /etc/bind/keys/dhcp-update.key
sudo chmod 640 /etc/bind/keys/dhcp-update.key
```

---

## 4. Configuration de BIND9

### 4.1 Inclure la clé

Dans `/etc/bind/named.conf.local` :

```conf
include "/etc/bind/keys/dhcp-update.key";
```

### 4.2 Zones DNS avec autorisations d'update

Exemple pour une zone directe :

```conf
zone "sio.lan" {
    type master;
    file "/etc/bind/zones/db.sio.lan";
    allow-update { key dhcp-update-key; };
};
```

Exemple pour une zone inverse :

```conf
zone "10.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.10";
    allow-update { key dhcp-update-key; };
};
```

Ajoutez `allow-update` dans chaque zone gérée dynamiquement.

### 4.3 Permissions pour les fichiers de zones

Les fichiers doivent appartenir à l’utilisateur `bind` :

```bash
sudo chown bind:bind /etc/bind/zones/db.*
sudo chmod 644 /etc/bind/zones/db.*
```

### 4.4 Désactivation ou ajustement AppArmor

BIND doit pouvoir créer les fichiers journal `.jnl`.

Solution simple : autoriser l’écriture dans `/etc/bind/zones`.

Modifier : `/etc/apparmor.d/usr.sbin.named`

Ajouter :

```
/etc/bind/zones/** rw,
```

Puis :

```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.named
sudo systemctl restart bind9
```

---

## 5. Configuration du serveur DHCP

### 5.1 Inclusion de la clé

Dans `/etc/dhcp/dhcpd.conf` ajouter :

```conf
include "/etc/bind/keys/dhcp-update.key";
```

### 5.2 Paramétrage DDNS

Exemple de configuration :

```conf
ddns-update-style interim;
ddns-domainname "sio.lan";
ddns-rev-domainname "in-addr.arpa";
update-static-leases on;
```

### 5.3 Paramétrage des mises à jour sécurisées

```conf
zone sio.lan. {
    primary 127.0.0.1;
    key dhcp-update-key;
}

zone 10.168.192.in-addr.arpa. {
    primary 127.0.0.1;
    key dhcp-update-key;
}
```

### 5.4 Déclaration d’un hôte

```conf
host knuckles {
    hardware ethernet 08:00:27:65:b7:5d;
    fixed-address 192.168.10.5;
}
```

---

## 6. Redémarrage et vérifications

### Redémarrer les services

```bash
sudo systemctl restart bind9
sudo systemctl restart isc-dhcp-server
```

### Vérifier la configuration

```bash
sudo named-checkconf
sudo named-checkzone sio.lan /etc/bind/zones/db.sio.lan
```

### Surveiller les logs

```bash
sudo tail -f /var/log/syslog | grep -E "dhcp|named"
```

Exemples de messages de succès :

```
Added new forward map from knuckles.sio.lan to 192.168.10.5
Added reverse map from 5.10.168.192.in-addr.arpa to knuckles.sio.lan
```

---

## 7. Forcer une mise à jour d’un client DHCP

Une mise à jour DDNS n’est envoyée que lorsque le client renouvelle son bail.

Pour forcer immédiatement :

### Sur Linux

```bash
sudo dhclient -r
sudo dhclient
```

### Sur Windows

```powershell
ipconfig /release
ipconfig /renew
```

---

## 8. Vérification dans les fichiers de zones

Les fichiers de zone ne sont mis à jour qu'en cas d'arrêt propre de BIND ou export du journal `.jnl`.

Pour forcer l’écriture :

```bash
sudo rndc sync -clean
```

---

## 9. Résumé des actions réalisées

1. Création d’une clé TSIG sécurisée.
2. Séparation de la clé dans un fichier dédié.
3. Configuration de BIND pour accepter les mises à jour dynamiques.
4. Ajustement d’AppArmor pour autoriser l’écriture des journaux de zone.
5. Configuration du serveur DHCP pour signer les mises à jour.
6. Tests de fonctionnement et analyse des logs.
7. Validation totale des mises à jour directes et inverses.

---

## 10. Conclusion

Le système DHCP–BIND est désormais entièrement opérationnel avec des mises à jour DNS dynamiques sécurisées. Toute nouvelle attribution ou modification d’adresse IP est automatiquement répercutée dans les enregistrements DNS correspondants, garantissant une cohérence parfaite entre infrastructure IP et DNS.
