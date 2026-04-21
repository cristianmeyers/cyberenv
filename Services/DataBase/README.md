# 🗄️ siodb : Serveur de Base de Données Centralisé (MariaDB 12.2.2)

Ce dépôt documente la configuration et le déploiement du serveur de base de données principal pour l'infrastructure de laboratoire **sio.lan**. Ce serveur héberge les bases de données de **GLPI** et **Wiki.js**, déployés sur `siolnx`.

## 🚀 Vue d'ensemble de l'infrastructure

**Ubuntu Minimized** sous Proxmox avec **MariaDB 12.2.2** (2026 LTS).

### 📌 Spécifications Réseau

| Paramètre                 | Valeur                 |
| ------------------------- | ---------------------- |
| **Hostname**              | `siodb`                |
| **FQDN**                  | `siodb.sio.lan`        |
| **Adresse IP**            | `192.168.10.5`         |
| **Masque de sous-réseau** | `255.255.255.0` (/24)  |
| **Passerelle**            | `192.168.10.254`       |
| **DNS Primaire**          | `192.168.10.4` (sioad) |
| **Domaine**               | `sio.lan`              |

## 🛠️ Configuration du Système

### 1. Réseau Statique (Netplan)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      dhcp4: no
      addresses: [192.168.10.5/24]
      nameservers:
        addresses: [192.168.10.4]
        search: [sio.lan]
      routes:
        - to: default
          via: 192.168.10.254
```

### 2. `/etc/hosts`

```text
127.0.0.1       localhost
127.0.1.1       siodb.sio.lan    siodb

# Infrastructure SIO
192.168.10.2    siodhcp.sio.lan  siodhcp
192.168.10.4    sioad.sio.lan    sioad
192.168.10.6    siolnx.sio.lan   siolnx
```

## 🗄️ MariaDB 12.2.2 (Zero-Configuration SSL)

### 1. Installation & Repo Officiel

```bash
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-12.2-repo
sudo apt install mariadb-server mariadb-client -y
sudo systemctl enable --now mariadb
sudo mysql_secure_installation
```

### 2. Configuration (`/etc/mysql/mariadb.conf.d/50-server.cnf`)

```ini
[mysqld]
bind-address = 0.0.0.0
require-secure-transport = OFF
```

> ⚠️ **Décision technique** : `require-secure-transport = OFF` est intentionnel.
> MariaDB 12.2.2 inclut le **Zero-Configuration SSL** — il génère automatiquement
> ses propres certificats et chiffre les connexions des clients compatibles.
> Le flag `OFF` ne désactive pas le chiffrement, il permet aux clients qui ne
> supportent pas le SSL automatique (comme PHP mysqli dans les conteneurs Docker)
> de se connecter sans être rejetés.
> Dans un environnement de production, on utiliserait WireGuard entre les serveurs
> pour chiffrer tout le trafic inter-serveurs au niveau réseau.

```bash
sudo systemctl restart mariadb
```

## 🔍 Tests de Connectivité

### Depuis siolnx (serveur GLPI/Wiki.js)

```bash
# Test de connexion simple
mysql -h 192.168.10.5 -u sio -psioPBA29200 glpidb

```

### Depuis Windows (PowerShell)

```powershell
Test-NetConnection -ComputerName 192.168.10.5 -Port 3306
# TcpTestSucceeded : True
```

### Débloquer un host bloqué (trop de tentatives)

Si MariaDB bloque un host après trop de tentatives échouées :

```sql
FLUSH HOSTS;
```

## 📝 Notes de Sécurité

| Aspect                      | État | Détail                                      |
| --------------------------- | ---- | ------------------------------------------- |
| HTTPS clients web           | ✅   | mkcert sur Traefik (siolnx)                 |
| Chiffrement DB ↔ conteneurs | ⚠️   | TCP sans chiffrement (réseau interne privé) |
| Zero-Config SSL MariaDB     | ✅   | Disponible, non obligatoire                 |
| Amélioration future         | 🔜   | WireGuard entre siolnx et siodb             |
