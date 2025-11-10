# DNS (Domain Name System)

Pour le service **DNS** j'ai choisi un **Ubuntu Live server 24.04 LTS** comme serveur principal puis `Bind9` comme service DNS. Ci-dessous il y aura la configuration en partant de zéro.

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
> - Aucune configuration personnalisée encore
> - Le serveur DNS ne répond à rien pour l’instant

**Sortie attendue :**

```
● named.service - BIND Domain Name Server
   Loaded: loaded (/lib/systemd/system/named.service; enabled; preset: enabled)
   Active: inactive (dead)
```

### ÉTAPE 2 : Configuration de named.conf

C’est le fichier principal de BIND9. Il dit à BIND où trouver les autres fichiers de configuration. C’est comme la table des matières d’un livre : il ne contient aucune règle, juste **3 include**.

**Configurer les 3 fichier a prendre en compte par le DNS : `sudo nano /etc/bind/named.conf` et coller :**

```bash
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/named.conf.default-zones";
```

> **RÈGLE D’OR :**
> NE JAMAIS toucher ce fichier après l’installation.
> Si on changes quoi que ce soit ici = **DNS mort**.
> Toujours laisser exactement ces 3 lignes.

### ÉTAPE 3 : Configuration de named.conf.options

C’est le cerveau de BIND9. Tout ce que fait le serveur DNS (où écouter, qui peut demander, récursion, forwarders…) se décide ici.

```bash
sudo nano /etc/bind/named.conf.options
```

**Et remplir avec**

```bash
options {
    directory "/var/cache/bind";

    # Autorise tout le monde à interroger (on est en lab)
    allow-query { any; };

    # On désactive la récursion pour l’instant (on ne forwarde pas encore)
    recursion no;

    # Écoute UNIQUEMENT sur 192.168.10.1 et localhost
    listen-on port 53 { 127.0.0.1; 192.168.10.2; };
    listen-on-v6 { none; };

    # Sécurité de base
    dnssec-validation auto;
    auth-nxdomain no;    # conforme RFC 1035
};
```

> **ATTENTION** à l'adresse IP

### ÉTAPE 4 : Configuration de named.conf.local

C’est là où on déclares tes zones personnelles (example.lan et sa zone inverse). C’est le seul fichier qu'on modifieras quand tu voudras ajouter un nouveau domaine.

**On ouvre le fichier :**

```bash
sudo nano /etc/bind/named.conf.local
```

**Et on remplis avec:**

```bash
zone "example.lan" {
    type master;
    file "/etc/bind/zones/db.example.lan";
    allow-transfer { none; };   # sécurité : personne ne copie la zone
};

zone "10.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.10";
    allow-transfer { none; };
};
```

### ÉTAPE 5 : Configuration de db.example.lan

C’est la base de données du domaine example.lan. Ici on dis : quel nom = quelle IP.

**On ouvre le fichier :**

```bash
sudo nano /etc/bind/zones/db.example.lan
```

**Et on remplis avec:**

```bash
$TTL 604800
@       IN      SOA     dhcp.example.lan. admin.example.lan. (
                              2025111001 ; Serial → augmente à chaque modif
                              604800     ; Refresh
                               86400     ; Retry
                              2419200    ; Expire
                               60480 )   ; Negative Cache TTL

@       IN      NS      dhcp.example.lan.     ; NS = ton serveur
dhcp    IN      A       192.168.10.1         ; dhcp.example.lan → 192.168.10.1
@       IN      A       192.168.10.1         ; example.lan → même IP
www     IN      CNAME   dhcp.example.lan.     ; www.example.lan → dhcp
gateway IN      A       192.168.10.1         ; gateway.example.lan → même IP
```
