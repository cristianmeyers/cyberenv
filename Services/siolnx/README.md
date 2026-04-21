# 📂 Configuration du Serveur `siolnx`

Ce document couvre la configuration de base du serveur Linux **`siolnx`** : réseau, DNS, Docker, mkcert et Traefik. C'est le socle commun sur lequel tournent tous les services conteneurisés (Wiki.js, GLPI, etc.).

---

## 📌 Spécifications Réseau

| Paramètre                 | Valeur                 |
| ------------------------- | ---------------------- |
| **Hostname**              | `siolnx`               |
| **FQDN**                  | `siolnx.sio.lan`       |
| **Adresse IP**            | `192.168.10.6`         |
| **Masque de sous-réseau** | `255.255.255.0` (/24)  |
| **Passerelle**            | `192.168.10.254`       |
| **DNS Primaire**          | `192.168.10.4` (sioad) |
| **Domaine**               | `sio.lan`              |

---

## 🛠️ Phase 1 : Configuration du Système

### 1.1 Réseau Statique (Netplan)

```bash
sudo nano /etc/netplan/00-netconfig.yaml
```

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      dhcp4: no
      addresses: [192.168.10.6/24]
      nameservers:
        addresses: [192.168.10.4]
        search: [sio.lan]
      routes:
        - to: default
          via: 192.168.10.254
```

```bash
sudo netplan apply
```

### 1.2 Résolution des noms (`/etc/hosts`)

```bash
sudo nano /etc/hosts
```

```text
127.0.0.1       localhost
127.0.1.1       siolnx.sio.lan    siolnx

# Infrastructure SIO
192.168.10.2    siodhcp.sio.lan     siodhcp
192.168.10.4    sioad.sio.lan       sioad
192.168.10.5    siodb.sio.lan       siodb
```

---

## 🐳 Phase 2 : Installation de Docker

```bash
sudo apt update && sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

Ajouter l'utilisateur courant au groupe Docker :

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Vérification :

```bash
docker --version
docker compose version
```

---

## 🔐 Phase 3 : Certificats HTTPS avec mkcert

### 3.1 Installation de mkcert

```bash
sudo apt install -y libnss3-tools curl
curl -Lo mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
sudo mv mkcert /usr/local/bin/mkcert
sudo chmod +x /usr/local/bin/mkcert
```

### 3.2 Création de la CA locale

```bash
mkcert -install
```

> La CA générée par mkcert doit être importée sur les postes clients pour que les certificats soient reconnus comme valides dans les navigateurs.

### 3.3 Génération des certificats

Les certificats sont générés une seule fois pour tous les services hébergés sur `siolnx` :

```bash
mkdir -p ~/docker-apps/traefik/certs
cd ~/docker-apps/traefik/certs
mkcert siolnx.sio.lan wiki.sio.lan glpi.sio.lan
```

Cela génère deux fichiers couvrant tous les domaines :

```
siolnx.sio.lan+2.pem      → certificat (SAN : siolnx, wiki, glpi)
siolnx.sio.lan+2-key.pem  → clé privée
```

> Pour ajouter un nouveau service, régénérer le certificat en ajoutant son domaine à la commande `mkcert`.

---

## ⚙️ Phase 4 : Déploiement de Traefik

Traefik est le reverse proxy commun à tous les services. Il est déployé une seule fois et partagé via un réseau Docker dédié.

### 4.1 Création du réseau Docker partagé

```bash
docker network create proxy-net
```

### 4.2 Arborescence des fichiers

```
~/docker-apps/
├── traefik/
│   ├── certs/
│   │   ├── siolnx.sio.lan+2.pem
│   │   └── siolnx.sio.lan+2-key.pem
│   └── certs.yml          ← configuration TLS dynamique
└── docker-compose.yml     ← contient le service Traefik
```

### 4.3 Configuration TLS dynamique (`certs.yml`)

```bash
nano ~/docker-apps/traefik/certs.yml
```

```yaml
tls:
  certificates:
    - certFile: /certs/siolnx.sio.lan+2.pem
      keyFile: /certs/siolnx.sio.lan+2-key.pem
```

### 4.4 `docker-compose.yml` - Service Traefik

```bash
nano ~/docker-apps/docker-compose.yml
```

```yaml
services:
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: always
    networks:
      - proxy-net
    ports:
      - "80:80"
      - "443:443"
      - "8888:8080" # Dashboard Traefik
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /home/sio/docker-apps/traefik/certs:/certs:ro
      - /home/sio/docker-apps/traefik/certs.yml:/etc/traefik/dynamic/certs.yml:ro
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=proxy-net
      - --providers.file.directory=/etc/traefik/dynamic
      - --entrypoints.web.address=:80
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --entrypoints.websecure.address=:443

networks:
  proxy-net:
    external: true
```

### 4.5 Lancement de Traefik

```bash
cd ~/docker-apps/
docker compose up -d traefik
```

### 4.6 Vérification

```bash
docker ps --filter "name=traefik"
# traefik doit être "Up"
```

Dashboard accessible sur : `http://siolnx.sio.lan:8888`

---

## 🔍 Maintenance

### Logs Traefik

```bash
docker logs -f traefik
```

### Redémarrage de Traefik

```bash
docker compose restart traefik
```

### Statut global des conteneurs

```bash
docker ps -a
```
