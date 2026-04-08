# 📂 Configuration du Service GLPI (`siolnx`)

GLPI centralise la gestion du parc informatique et le support utilisateur (ticketing) pour le projet CyberEnv. Ce guide couvre uniquement le déploiement du service. Le socle commun (Docker, mkcert, Traefik, réseau Docker `proxy-net`) est documenté dans `siolnx.md`.

## 📝 Spécifications du Service

| Paramètre            | Valeur                                               |
| -------------------- | ---------------------------------------------------- |
| **Hôte**             | `siolnx` — `192.168.10.6`                            |
| **Accès**            | `https://glpi.sio.lan`                               |
| **Base de données**  | `siodb` — `192.168.10.5`                             |
| **DB**               | `glpidb`                                             |
| **Communication DB** | Réseau local (pas de SSL pour l'instant — VPN prévu) |

---

## 🗄️ Phase 1 : Préparation de la Base de Données (sur `siodb`)

Se connecter à `siodb` et exécuter :

```sql
CREATE DATABASE IF NOT EXISTS glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'sio'@'192.168.10.6' IDENTIFIED BY 'sioPBA2026';
GRANT ALL PRIVILEGES ON glpidb.* TO 'sio'@'192.168.10.6';
FLUSH PRIVILEGES;
```

| Paramètre    | Valeur         |
| ------------ | -------------- |
| Serveur SQL  | `192.168.10.5` |
| Nom de la DB | `glpidb`       |
| Utilisateur  | `sio`          |
| Accès depuis | `192.168.10.6` |

> **Note :** L'utilisateur `sio` est peut-être déjà créé si Wiki.js a été installé avant. Dans ce cas, le `CREATE USER` échouera silencieusement grâce au `IF NOT EXISTS` — seul le `GRANT` sur `glpidb` est nécessaire.

---

## ⚙️ Phase 2 : Déploiement Docker Compose

Créer le répertoire du service :

```bash
mkdir -p ~/docker-apps/glpi
nano ~/docker-apps/glpi/docker-compose.yml
```

```yaml
services:
  glpi:
    image: glpi/glpi:latest
    container_name: glpi-app
    restart: always
    networks:
      - proxy-net
    environment:
      - TIMEZONE=Europe/Paris
      - DB_HOST=192.168.10.5
      - DB_NAME=glpidb
      - DB_USER=sio
      - DB_PASSWORD=sioPBA2026
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.glpi.rule=Host(`glpi.sio.lan`)"
      - "traefik.http.routers.glpi.entrypoints=websecure"
      - "traefik.http.routers.glpi.tls=true"
      - "traefik.http.services.glpi.loadbalancer.server.port=80"

networks:
  proxy-net:
    external: true
```

---

## 🚀 Phase 3 : Lancement et Initialisation

### 3.1 Démarrage du conteneur

```bash
cd ~/docker-apps/glpi/
docker compose up -d
```

### 3.2 Vérification

```bash
docker ps --filter "name=glpi-app"
# glpi-app doit être "Up"
```

### 3.3 Assistant de configuration GLPI

1. Accéder à `https://glpi.sio.lan`
2. Lors de l'étape de connexion à la base de données :
   - **Serveur SQL :** `192.168.10.5`
   - **Utilisateur :** `sio`
   - **Mot de passe :** `sioPBA2026`
   - **Base de données :** `glpidb`

Vérifier que le routeur `glpi` apparaît bien dans le dashboard Traefik : `http://siolnx.sio.lan:8888`

---

## 🔍 Maintenance

### Logs

```bash
docker logs -f glpi-app
```

### Redémarrage

```bash
cd ~/docker-apps/glpi/
docker compose restart glpi
```

### Statut

```bash
docker ps --filter "name=glpi-app"
```
