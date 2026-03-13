# 📚 Configuration du Service Wiki.js (`siolnx`)

Ce guide détaille l'installation de **Wiki.js**, la plateforme de base de connaissances pour l'infrastructure. Le service fonctionne sur **`siolnx`** via Docker, stocke son contenu dans la base MariaDB de **`siodb`**, et est exposé via le reverse proxy **Traefik**.

## 📝 Spécifications du Service

- **Hôte de déploiement :** `siolnx` — `192.168.10.6`
- **Technologie :** Docker (Node.js)
- **Accès :** `http://wiki.sio.lan` (port 80 via Traefik)
- **Base de données (Externe) :** `192.168.10.5` (`siodb`)
- **DNS associé :** `wiki.sio.lan → 192.168.10.6`

> ⚠️ Le port `3000` n'est plus exposé directement. Tout le trafic passe par Traefik sur le port `80`.

---

## 🛠 Phase 1 : Préparation de l'environnement

### 1.1 Création de l'arborescence

```bash
mkdir -p ~/docker-apps/wiki-config
cd ~/docker-apps/
```

### 1.2 Registres DNS (sur le serveur Samba 4)

Avant de déployer, s'assurer que les enregistrements DNS sont créés :

```bash
# Enregistrement A principal de la machine (si pas encore fait)
samba-tool dns add localhost sio.lan siolnx A 192.168.10.6 -U Administrator

# Enregistrement CNAME pour Wiki.js
samba-tool dns add localhost sio.lan wiki CNAME siolnx.sio.lan -U Administrator
```

Vérification :

```bash
nslookup wiki.sio.lan
# Doit retourner 192.168.10.6
```

---

## ⚙️ Phase 2 : Configuration du Service

L'avantage de Wiki.js est que la configuration de la base de données est injectée directement via les variables d'environnement. Traefik détecte automatiquement le conteneur via les `labels`.

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

  # --- Conteneur Wiki.js ---
  wikijs:
    image: requarks/wiki:2
    container_name: wiki-app
    restart: always
    environment:
      - DB_TYPE=mariadb
      - DB_HOST=192.168.10.5
      - DB_PORT=3306
      - DB_NAME=wikidb
      - DB_USER=sio
      - DB_PASS=sioPBA2026
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wikijs.rule=Host(`wiki.sio.lan`)"
      - "traefik.http.routers.wikijs.entrypoints=web"
      - "traefik.http.services.wikijs.loadbalancer.server.port=3000"
```

> ℹ️ La directive `ports` a été retirée du conteneur Wiki.js. Traefik gère l'exposition via les `labels`.

---

## 🗄️ Phase 3 : Préparation de la Base de Données (`siodb`)

Avant de déployer, les ressources doivent être créées sur **`siodb`** (`192.168.10.5`) :

```sql
CREATE DATABASE wikidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'sio'@'192.168.10.6' IDENTIFIED BY 'sioPBA2026';
GRANT ALL PRIVILEGES ON wikidb.* TO 'sio'@'192.168.10.6';
FLUSH PRIVILEGES;
```

| Paramètre    | Valeur                  |
| ------------ | ----------------------- |
| Serveur SQL  | `192.168.10.5`          |
| Nom de la DB | `wikidb`                |
| Utilisateur  | `sio`                   |
| Accès depuis | `192.168.10.6` (siolnx) |

---

## 🚀 Phase 4 : Activation et Initialisation

### 4.1 Déploiement du service

```bash
cd ~/docker-apps/
docker compose up -d
```

Vérifier que les deux conteneurs sont actifs :

```bash
docker ps
# traefik et wiki-app doivent être "Up"
```

### 4.2 Configuration initiale (Setup)

1. Accédez à `http://wiki.sio.lan`
2. Créez le compte administrateur du Wiki
3. Configurez l'URL publique sur `http://wiki.sio.lan` pour assurer le bon fonctionnement des liens internes

### 4.3 Dashboard Traefik

Accédez à `http://siolnx.sio.lan:8888` pour vérifier que le routeur `wikijs` est bien détecté et actif.

---

## 🔍 Phase 5 : Maintenance et Logs

### 5.1 Vérification de la connectivité DB

```bash
docker logs -f wiki-app
```

### 5.2 Logs Traefik

```bash
docker logs -f traefik
```

### 5.3 Statut des conteneurs

```bash
docker ps --filter "name=wiki-app"
docker ps --filter "name=traefik"
```

### 5.4 Redémarrage

```bash
docker compose restart wikijs
```
