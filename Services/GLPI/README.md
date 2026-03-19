# 📂 Configuration du Service GLPI (`siolnx`)

Ce guide détaille le déploiement conteneurisé de **GLPI 10** sur le serveur **`siolnx`**. Ce service centralise la gestion du parc informatique et le support utilisateur (Ticketing) pour le projet **CyberEnv**. L'instance utilise une base de données MariaDB externe sur `siodb`, est exposée via **Traefik** en **HTTPS**, et communique avec la base de données via **SSL**.

## 📝 Spécifications du Service

- **Hôte de déploiement :** `siolnx` — `192.168.10.6`
- **Technologie :** Docker / Docker Compose + Traefik
- **Accès :** `https://glpi.sio.lan` (HTTPS via Traefik)
- **Base de données (Externe) :** `192.168.10.5` (`siodb`)
- **DNS associé :** `glpi.sio.lan → 192.168.10.6`
- **Certificats HTTPS :** générés avec `mkcert`
- **Certificats DB :** générés avec `openssl`

---

## 🛠 Phase 1 : Préparation de l'environnement

### 1.1 Création de l'arborescence

```bash
mkdir -p ~/docker-apps/traefik/certs
mkdir -p ~/docker-apps/ssl
cd ~/docker-apps/
```

### 1.2 Registres DNS (sur le serveur Samba 4)

```bash
# Enregistrement A principal de la machine
samba-tool dns add localhost sio.lan siolnx A 192.168.10.6 -U Administrator

# Enregistrement CNAME pour GLPI
samba-tool dns add localhost sio.lan glpi CNAME siolnx.sio.lan -U Administrator
```

Vérification :

```bash
nslookup glpi.sio.lan
# Doit retourner 192.168.10.6
```

---

## 🔐 Phase 2 : Certificats HTTPS avec mkcert

### 2.1 Installation de mkcert sur `siolnx`

```bash
sudo apt install -y libnss3-tools curl
curl -Lo mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-amd64
sudo mv mkcert /usr/local/bin/mkcert
sudo chmod +x /usr/local/bin/mkcert
```

### 2.2 Création de la CA locale et des certificats

```bash
mkcert -install

cd ~/docker-apps/traefik/certs
mkcert wiki.sio.lan glpi.sio.lan siolnx.sio.lan
```

Génère deux fichiers :

```
wiki.sio.lan+2.pem      → certificat
wiki.sio.lan+2-key.pem  → clé privée
```

### 2.3 Fichier de configuration dynamique Traefik

```bash
nano ~/docker-apps/traefik/certs.yml
```

Contenu :

```yaml
tls:
  certificates:
    - certFile: /certs/wiki.sio.lan+2.pem
      keyFile: /certs/wiki.sio.lan+2-key.pem
```

---

## 🔒 Phase 3 : Certificats SSL pour MariaDB

Ces certificats sécurisent la communication entre `siolnx` et `siodb`.

### 3.1 Génération sur `siodb`

```bash
sudo mkdir -p /etc/mysql/ssl
cd /etc/mysql/ssl

# CA
sudo openssl genrsa 2048 | sudo tee ca-key.pem
sudo openssl req -new -x509 -nodes -days 3650 \
  -key ca-key.pem -out ca-cert.pem \
  -subj "/CN=SIO-MariaDB-CA"

# Certificat serveur
sudo openssl genrsa 2048 | sudo tee server-key.pem
sudo openssl req -new -key server-key.pem \
  -out server-req.pem -subj "/CN=siodb.sio.lan"
sudo openssl x509 -req -days 3650 \
  -in server-req.pem -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out server-cert.pem

# Certificat client
sudo openssl genrsa 2048 | sudo tee client-key.pem
sudo openssl req -new -key client-key.pem \
  -out client-req.pem -subj "/CN=siolnx.sio.lan"
sudo openssl x509 -req -days 3650 \
  -in client-req.pem -CA ca-cert.pem -CAkey ca-key.pem \
  -CAcreateserial -out client-cert.pem

# Permissions
sudo chown -R mysql:mysql /etc/mysql/ssl
sudo chmod 600 /etc/mysql/ssl/*
```

### 3.2 Configuration MariaDB sur `siodb`

```bash
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Ajouter dans `[mysqld]` :

```ini
[mysqld]
ssl-ca   = /etc/mysql/ssl/ca-cert.pem
ssl-cert = /etc/mysql/ssl/server-cert.pem
ssl-key  = /etc/mysql/ssl/server-key.pem
require-secure-transport = ON
```

```bash
sudo systemctl restart mariadb
```

### 3.3 Copier les certificats client sur `siolnx`

```bash
scp sio@192.168.10.5:/etc/mysql/ssl/ca-cert.pem ~/docker-apps/ssl/
scp sio@192.168.10.5:/etc/mysql/ssl/client-cert.pem ~/docker-apps/ssl/
scp sio@192.168.10.5:/etc/mysql/ssl/client-key.pem ~/docker-apps/ssl/
```

---

## 🗄️ Phase 4 : Préparation de la Base de Données (`siodb`)

```sql
CREATE DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'sio'@'192.168.10.6' IDENTIFIED BY 'sioPBA2026';
GRANT ALL PRIVILEGES ON glpidb.* TO 'sio'@'192.168.10.6';
FLUSH PRIVILEGES;
```

| Paramètre    | Valeur                  |
| ------------ | ----------------------- |
| Serveur SQL  | `192.168.10.5`          |
| Nom de la DB | `glpidb`                |
| Utilisateur  | `sio`                   |
| Accès depuis | `192.168.10.6` (siolnx) |

---

## ⚙️ Phase 5 : Déploiement via Docker Compose

### 5.1 Configuration du fichier `docker-compose.yml`

```yaml
services:
  # --- Traefik Reverse Proxy ---
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: always
    ports:
      - "80:80"
      - "443:443"
      - "8888:8080" # Dashboard : http://siolnx.sio.lan:8888
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /home/sio/docker-apps/traefik/certs:/certs:ro
      - /home/sio/docker-apps/traefik/certs.yml:/etc/traefik/dynamic/certs.yml:ro
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.file.directory=/etc/traefik/dynamic
      - --entrypoints.web.address=:80
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --entrypoints.websecure.address=:443

  # --- Conteneur GLPI ---
  glpi:
    image: glpi/glpi:latest
    container_name: glpi-app
    restart: always
    volumes:
      - /home/sio/docker-apps/ssl:/ssl:ro
    environment:
      - TIMEZONE=Europe/Paris
      - DB_HOST=192.168.10.5
      - DB_NAME=glpidb
      - DB_USER=sio
      - DB_PASSWORD=sioPBA2026
      - DB_SSL=true
      - DB_SSL_CA=/ssl/ca-cert.pem
      - DB_SSL_CERT=/ssl/client-cert.pem
      - DB_SSL_KEY=/ssl/client-key.pem
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.glpi.rule=Host(`glpi.sio.lan`)"
      - "traefik.http.routers.glpi.entrypoints=websecure"
      - "traefik.http.routers.glpi.tls=true"
      - "traefik.http.services.glpi.loadbalancer.server.port=80"
```

---

## 🚀 Phase 6 : Activation

### 6.1 Lancement des conteneurs

```bash
cd ~/docker-apps/
docker compose down
docker compose up -d
```

### 6.2 Vérification

```bash
docker ps
# traefik et glpi-app doivent être "Up"
```

### 6.3 Assistant de configuration GLPI

1. Accédez à `https://glpi.sio.lan`
2. Lors de l'étape de connexion à la base de données :
   - **Serveur SQL :** `192.168.10.5`
   - **Utilisateur :** `sio`
   - **Base de données :** `glpidb`

### 6.4 Dashboard Traefik

Accédez à `http://siolnx.sio.lan:8888` pour vérifier que le routeur `glpi` est actif et en HTTPS.

---

## 🔍 Phase 7 : Maintenance et Logs

### 7.1 Logs GLPI

```bash
docker logs -f glpi-app
```

### 7.2 Logs Traefik

```bash
docker logs -f traefik
```

### 7.3 Statut des conteneurs

```bash
docker ps --filter "name=glpi-app"
docker ps --filter "name=traefik"
```

### 7.4 Redémarrage

```bash
docker compose restart glpi
```
