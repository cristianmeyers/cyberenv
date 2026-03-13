# 🗄️ siodb : Serveur de Base de Données Centralisé (MariaDB)

Ce dépôt documente la configuration et le déploiement du serveur de base de données principal pour l'infrastructure de laboratoire **sio.lan**. Ce serveur centralise les données pour les services **GLPI**, **Wiki.js** et **Nextcloud**.

## 🚀 Vue d'ensemble de l'infrastructure

Le serveur est basé sur une installation **Ubuntu Minimized**, choisie pour sa légèreté, sa sécurité accrue et sa faible consommation de ressources sous Proxmox.

### 📌 Spécifications Réseau

| Paramètre                 | Valeur                   |
| ------------------------- | ------------------------ |
| **Hostname**              | `siodb`                  |
| **FQDN**                  | `siodb.sio.lan`          |
| **Adresse IP**            | `192.168.10.5`           |
| **Masque de sous-réseau** | `255.255.255.0` (/24)    |
| **Passerelle (Gateway)**  | `192.168.10.1` (OpenWRT) |
| **DNS Primaire**          | `192.168.10.4` (sioad)   |
| **Domaine**               | `sio.lan`                |

---

## 🛠️ Configuration du Système

### 1. Configuration Réseau (Netplan)

Le fichier `/etc/netplan/00-installer-config.yaml` a été configuré pour une IP statique afin de garantir la disponibilité du service même en cas d'indisponibilité du serveur DHCP :

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s1:
      dhcp4: no
      addresses:
        - 192.168.10.5/24
      nameservers:
        addresses: [192.168.10.4]
        search: [sio.lan]
      routes:
        - to: default
          via: 192.168.10.1
```

### 2. Résolution de noms locale (`/etc/hosts`)

```text
127.0.0.1       localhost
127.0.1.1       siodb.sio.lan    siodb

# Infrastructure SIO
192.168.10.4    sioad.sio.lan     sioad
192.168.10.2    siodhcp.sio.lan   siodhcp
192.168.10.1    siogw.sio.lan     siogw

```

---

## 🗄️ Service MariaDB

### 1. Installation

```bash
sudo apt update && sudo apt install mariadb-server -y

```

### 2. Configuration de l'accès distant

Pour permettre aux serveurs d'applications de se connecter, la directive `bind-address` a été modifiée dans `/etc/mysql/mariadb.conf.d/50-server.cnf` :

```ini
bind-address = 0.0.0.0

```

### 3. Utilisateurs et Bases de Données (Préparation)

Les comptes suivants ont été créés avec des privilèges restreints aux bases de données respectives :

- **GLPI :** `glpi_user` sur `glpidb`
- **Wiki.js :** `wiki_user` sur `wikidb`
- **Nextcloud :** `nc_user` sur `nextclouddb`

---

## 🔍 Tests et Vérifications

### Test de connectivité (depuis Windows)

Depuis un client Windows (`siowin`), la connectivité au port MariaDB est validée via PowerShell :

```powershell
Test-NetConnection -ComputerName 192.168.10.5 -Port 3306

```

**Résultat attendu :** `TcpTestSucceeded : True`

---
