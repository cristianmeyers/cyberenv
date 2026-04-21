# 📂 Configuration du Serveur DHCP Kea (`siodhcp`)

Ce guide détaille l'installation et la sécurisation du service DHCP pour le projet **CyberEnv**. Ce serveur distribue les adresses IP sur le segment `192.168.10.0/24` et oriente les clients vers le contrôleur de domaine pour la résolution DNS.

## 📝 Spécifications Réseau

- **Hostname :** `siodhcp`
- **IP Statique :** `192.168.10.2`
- **Passerelle (Gateway) :** `192.168.10.1`
- **DNS Primaire (AD) :** `192.168.10.4`
- **Domaine :** `sio.lan`
- **Plage d'adresses (Pool) :** `192.168.10.50` - `192.168.10.150`

## 🛠 Phase 1 : Préparation du Système

Avant l'installation, il est impératif que la VM possède une identité propre et une connectivité stable.

### 1.1 Nom d'hôte

```bash
sudo hostnamectl set-hostname siodhcp
exec bash

```

### 1.2 Configuration Réseau (Netplan)

Éditez votre fichier de configuration réseau (généralement dans `/etc/netplan/`).

```yaml
network:
  version: 2
  ethernets:
    ens18: # Nom de votre interface
      addresses:
        - 192.168.10.2/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.4, 8.8.8.8]
        search: [sio.lan]
```

`sudo netplan apply`

## 📦 Phase 2 : Installation et Authentification

Kea utilise un agent de contrôle pour gérer le service via une API. Lors de l'installation, une interface bleue s'affichera.

### 2.1 Installation des paquets

```bash
sudo apt update && sudo apt install -y kea-dhcp4-server kea-ctrl-agent

```

### 2.2 Écran de configuration (Blue Screen)

Lorsqu'on vous demande de configurer l'authentification de l'agent de contrôle :

1. Choisissez l'option **3. configured_password**.
2. Saisissez le mot de passe : `sioPBA29200`.

## ⚙️ Phase 3 : Configuration des Services

### 3.1 Agent de Contrôle (`/etc/kea/kea-ctrl-agent.conf`)

Ce service sécurise l'accès à l'API Kea.

```json
{
  "Control-agent": {
    "http-host": "127.0.0.1",
    "http-port": 8000,
    "authentication": {
      "type": "basic",
      "clients": [
        {
          "user": "kea-api",
          "password": "sioPBA29200"
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
```

### 3.2 Moteur DHCPv4 (`/etc/kea/kea-dhcp4.conf`)

C'est ici que l'on définit la distribution des adresses IP.

```json
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": ["ens18"]
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
        "pools": [{ "pool": "192.168.10.50 - 192.168.10.150" }],
        "option-data": [
          { "name": "routers", "data": "192.168.10.1" },
          { "name": "domain-name-servers", "data": "192.168.10.4" },
          { "name": "domain-name", "data": "sio.lan" }
        ]
      }
    ],
    "loggers": [
      {
        "name": "kea-dhcp4",
        "output_options": [{ "output": "/var/log/kea-dhcp4.log" }],
        "severity": "INFO"
      }
    ]
  }
}
```

## 🚀 Phase 4 : Activation et Monitoring

### 4.1 Démarrage des services

```bash
sudo touch /var/log/kea-dhcp4.log
sudo chown _kea:_kea /var/log/kea-dhcp4.log
sudo systemctl restart kea-ctrl-agent kea-dhcp4-server
sudo systemctl enable kea-ctrl-agent kea-dhcp4-server

```

### 4.2 Vérification des logs (Temps réel)

Pour voir si un client (ex: Windows) demande une IP, utilisez :

```bash
sudo tail -f /var/log/kea-dhcp4.log

```

### 4.3 Consultation des baux (Leases)

Pour voir la liste des machines connectées et leurs IPs :

```bash
cat /var/lib/kea/kea-leases4.csv

```
