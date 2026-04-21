# 📚 Configuration du Service Wiki.js (`siolnx`)

Wiki.js est la plateforme de base de connaissances du projet. Ce guide couvre uniquement le déploiement du service. Le socle commun (Docker, mkcert, Traefik, réseau Docker `proxy-net`) est documenté dans `siolnx.md`.

## 📝 Spécifications du Service

| Paramètre            | Valeur                                               |
| -------------------- | ---------------------------------------------------- |
| **Hôte**             | `siolnx` - `192.168.10.6`                            |
| **Accès**            | `https://wiki.sio.lan`                               |
| **Base de données**  | `siodb` - `192.168.10.5`                             |
| **DB**               | `wikidb`                                             |
| **Communication DB** | Réseau local (pas de SSL pour l'instant — VPN prévu) |

---

## 🗄️ Phase 1 : Préparation de la Base de Données (sur `siodb`)

Se connecter à `siodb` et exécuter :

```sql
CREATE DATABASE IF NOT EXISTS wikidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'sio'@'192.168.10.6' IDENTIFIED BY 'sioPBA2026';
GRANT ALL PRIVILEGES ON wikidb.* TO 'sio'@'192.168.10.6';
FLUSH PRIVILEGES;
```

| Paramètre    | Valeur         |
| ------------ | -------------- |
| Serveur SQL  | `192.168.10.5` |
| Nom de la DB | `wikidb`       |
| Utilisateur  | `sio`          |
| Accès depuis | `192.168.10.6` |

---

## ⚙️ Phase 2 : Déploiement Docker Compose

Créer le répertoire du service :

```bash
mkdir -p ~/docker-apps/wikijs
nano ~/docker-apps/wikijs/docker-compose.yml
```

```yaml
services:
  wikijs:
    image: requarks/wiki:2
    container_name: wiki-app
    restart: always
    networks:
      - proxy-net
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
      - "traefik.http.routers.wikijs.entrypoints=websecure"
      - "traefik.http.routers.wikijs.tls=true"
      - "traefik.http.services.wikijs.loadbalancer.server.port=3000"

networks:
  proxy-net:
    external: true
```

---

## 🚀 Phase 3 : Lancement et Initialisation

### 3.1 Démarrage du conteneur

```bash
cd ~/docker-apps/wikijs/
docker compose up -d
```

### 3.2 Vérification

```bash
docker ps --filter "name=wiki-app"
# wiki-app doit être "Up"
```

### 3.3 Configuration initiale

1. Accéder à `https://wiki.sio.lan`
2. Créer le compte administrateur
3. Configurer l'URL publique sur `https://wiki.sio.lan`

Vérifier que le routeur `wikijs` apparaît bien dans le dashboard Traefik : `http://siolnx.sio.lan:8888`

---

## 🔍 Maintenance

### Logs

```bash
docker logs -f wiki-app
```

### Redémarrage

```bash
cd ~/docker-apps/wikijs/
docker compose restart wikijs
```

### Statut

```bash
docker ps --filter "name=wiki-app"
```
