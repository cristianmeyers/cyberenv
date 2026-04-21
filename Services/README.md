# 📂 Répertoire des Services (CyberEnv)

Bienvenue dans le répertoire `Services`. Ce dossier centralise toutes les documentations, scripts de déploiement et fichiers de configuration (fichiers `.yml`, scripts bash, configurations réseau) relatifs aux différents services de l'infrastructure **CyberEnv**.

L'objectif de ce répertoire est de maintenir une infrastructure en tant que code `IaC` claire, modulaire et facilement reproductible.

## 🗂️ Architecture des Services

Chaque sous-dossier correspond à un service ou un rôle spécifique au sein de notre environnement. Voici un aperçu de leur contenu :

- **`ActiveDirectory/`** : Configuration du contrôleur de domaine (Samba4 / Windows Server), gestion des utilisateurs et des stratégies (GPO).
- **`DHCP/`** : Fichiers de configuration pour l'attribution dynamique des adresses IP sur le réseau local.
- **`DNS/`** : Paramétrage de la résolution de noms de domaine locaux (zone `sio.lan`).
- **`DataBase/`** : Scripts d'initialisation SQL, configuration du moteur de base de données (MariaDB - `siodb`) et gestion des privilèges.
- **`Fog/`** : Déploiement et configuration du serveur FOG Project pour le clonage et le déploiement d'images systèmes sur le parc.
- **`GLPI/`** : Fichiers de déploiement (Docker Compose) pour l'outil de gestion de parc informatique et de helpdesk (Ticketing).
- **`Wiki/`** : Déploiement conteneurisé de Wiki.js, la base de connaissances technique de l'infrastructure.
- **`scripts/`** : Scripts utilitaires globaux pour l'automatisation, la maintenance, ou les sauvegardes de l'environnement.
- **`siolnx/`** : Configuration du serveur Linux Core (`siolnx`), incluant la configuration réseau (Netplan), la génération de certificats locaux (`mkcert`) et le Reverse Proxy centralisé (**Traefik**).

---

## 🚀 Comment utiliser ce répertoire ?

Pour installer, configurer ou maintenir un service spécifique :

1. Naviguez dans le dossier correspondant au service ciblé.
2. Consultez la documentation ou le fichier de configuration présent à l'intérieur pour obtenir les spécifications réseau, les commandes Docker ou les instructions étape par étape.

> 💡 **Note d'architecture :** L'exposition web sécurisée (HTTPS) des services applicatifs conteneurisés tels que **GLPI** et le **Wiki** est centralisée et gérée dynamiquement par Traefik depuis le nœud principal `siolnx`.
