# 📂 Configuration du Service GLPI (`siolnx`)

Ce guide détaille le déploiement conteneurisé de **GLPI 10** sur le serveur **`siolnx`**. Ce service centralise la gestion du parc informatique et le support utilisateur (Ticketing) pour le projet **CyberEnv**. L'instance utilise une base de données MariaDB externe située sur le serveur `siodb`, et est exposée via le reverse proxy **Traefik**.

## 📝 Spécifications du Service

- **Hôte de déploiement :** `siolnx` — `192.168.10.6`
- **Technologie :** Docker / Docker Compose
- **Accès :** `http://glpi.sio.lan` (port 80 via Traefik)
- **Base de données (Externe) :** `192.168.10.5` (`siodb`)
- **DNS associé :** `glpi.sio.lan → 192.168.10.6`

> ⚠️ Le port `8080` n'est plus exposé directement. Tout le trafic passe par Traefik sur le port `80`.

---

## 🛠 Phase 1 : Préparation de l'environnement

### 1.1 Création de l'arborescence

```bash
mkdir -p ~/docker-apps/glpi
cd ~/docker-apps/
```

### 1.2 Registres DNS (sur le serveur Samba 4)

Avant de déployer, s'assurer que les enregistrements DNS sont créés :

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

## ⚙️ Phase 2 : Déploiement via Docker Compose

Le fichier `docker-compose.yml` intègre **Traefik** comme reverse proxy et **GLPI** comme service applicatif. Traefik détecte automatiquement le conteneur via les `labels`.

### 2.1 Configuration du fichier `docker-compose.yml`

```yaml
services:
  # --- Traefik Reverse Proxy ---
  traefik:
    image: traefik:v3
    container_name: traefik
    restart: always
    ports:
      - "80:80"
      - "8888:8080" # Dashboard Traefik : http://siolnx.sio.lan:8888
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80

  # --- Conteneur GLPI ---
  glpi:
    image: glpi/glpi:latest
    container_name: glpi-app
    restart: always
    environment:
      - TIMEZONE=Europe/Paris
      - DB_HOST=192.168.10.5
      - DB_NAME=glpidb
      - DB_USER=sio
      - DB_PASSWORD=sioPBA2026
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.glpi.rule=Host(`glpi.sio.lan`)"
      - "traefik.http.routers.glpi.entrypoints=web"
      - "traefik.http.services.glpi.loadbalancer.server.port=80"
```

> ℹ️ La directive `ports` a été retirée du conteneur GLPI. Traefik gère l'exposition via les `labels`.

---

## 🗄️ Phase 3 : Préparation de la Base de Données (`siodb`)

Avant de finaliser l'installation, les ressources doivent être créées sur **`siodb`** (`192.168.10.5`) :

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

## 🚀 Phase 4 : Activation et Installation Web

### 4.1 Lancement des conteneurs

```bash
cd ~/docker-apps/
docker compose up -d
```

Vérifier que les deux conteneurs sont actifs :

```bash
docker ps
# traefik et glpi-app doivent être "Up"
```

### 4.2 Assistant de configuration

1. Accédez à `http://glpi.sio.lan`
2. Lors de l'étape de connexion à la base de données :
   - **Serveur SQL :** `192.168.10.5`
   - **Utilisateur :** `sio`
   - **Base de données :** Sélectionner `glpidb`

### 4.3 Dashboard Traefik

Accédez à `http://siolnx.sio.lan:8888` pour vérifier que le routeur `glpi` est bien détecté et actif.

---

## 🔍 Phase 5 : Maintenance et Logs

### 5.1 Logs du conteneur GLPI

```bash
docker logs -f glpi-app
```

### 5.2 Logs Traefik

```bash
docker logs -f traefik
```

### 5.3 Statut des conteneurs

```bash
docker ps --filter "name=glpi-app"
docker ps --filter "name=traefik"
```

### 5.4 Redémarrage

```bash
docker compose restart glpi
```
