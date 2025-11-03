# Infrastructure de la salle

## Topologie : Tree (arbre)

### Vue d'ensemble

J'ai choisie la topologie en **arbre** (tree) parce-qu'elle permet une hiérarchie claire : un **nœud racine** connecté à des **branches** (VLANs / sous-réseaux) qui desservent des **feuilles** (postes, serveurs, cibles vulnérables). En outre, elle permet de :

- faciliter l’isolation entre groupes d’apprenants ;
- permettre d’appliquer des règles de filtrage par branche ;
- ajouter des nouvelles branches/sous-réseaux si besoin.

## Diagramme :

```
                         ┌────────────────────┐
                         │     Internet       │
                         └─────────┬──────────┘
                                   │
                        ┌──────────┴───────────┐
                        │        Routeur       │
                        │                      │
                        └──────────┬───────────┘
                                   │  (Trunk)
┌──────────────────────────────────────────────────────────────────────┐
│                              Switch                                  │
└────┬─────────────┬────────────┬────────────┬───────────┬───────────┬─┘
     │             │            │            │           │           │
     │             │            │            │           │           │
   VLAN 10      VLAN 20      VLAN 30    VLAN 40    VLAN 50     VLAN 60
  (Serveurs)    (Backup)       (IT)     (Invités)   (Wi-Fi)     (VM Hosts)
     │             │            │            │           │           │
┌────┴───────┐  ┌──┴──────┐  ┌──┴──────┐  ┌──┴─────┐  ┌──┴────┐  ┌───┴────┐
│ Web / DB   │  │ NAS/    │  │ Admin   │  │ Guest  │  │ AP(s) │  │ Hyper- │
│ / DNS /... │  │ Backup  │  │ Consoles│  │ Clients│  │       │  │ viser  │
└────────────┘  └─────────┘  └─────────┘  └────────┘  └───────┘  └────────┘


```

## Matériel (à revoir)

- 1 routeur/firewall (physique ou VM + pfSense/OPNsense)
- 1 switch manageable (VLANs) + câblage
- 1 NAS / serveur de stockage pour images et backups
- Un ou plusieurs serveurs d’hyperviseur (Proxmox, ESXi, KVM) ou une ferme Docker selon ton choix d’orchestration
- Option : Raspberry Pi / mini PC pour jump host ou services légers

## Plan d’adressage (Vlans)

Utiliser un plan IP privé cohérent — exemple en RFC1918 :

- **VLAN 10 (Serveur)** : `192.168.10.0/24` (DNS, DHCP, TFTP, etc.)
- **VLAN 20 (Backup)** : `192.168.20.0/24` (Backup dns, serveur fichier, etc.)
- **VLAN 30 (Admin)** : `192.168.30.0/24` (host des edutians salle cyber)
- **VLAN 40 (Invités)** : `192.168.40.0/24` (Invités, machines isolées)
- **VLAN 50 (Wi-fi)** : `192.168.50.0/24` (Invités, BYOD, etc.)
- **VLAN 60 (VMs)** : `192.168.60.0/24` (machines vulnérables, isolées)

> Note: Le fichier `dhcp.conf` possede toute la configuration et plan d'addressage du serveur DHCP

## VLANs et isolation (à revoir)

- Chaque **niveau / groupe** d’exercices a son propre VLAN/sous-réseau pour éviter les fuites.
- J'ai appliqué des **ACLs** sur le routeur d’agrégation :

- Management ↔ everything : accès restreint aux administrateurs.
- Lab VLAN ↔ Services VLAN : accès limité (seulement aux ports nécessaires).
- Lab VLAN → Internet : bloqué par défaut (autoriser seulement si nécessaire et audité).

- Utiliser des **firewalls logiciels** sur les cibles pour ajouter une couche de protection interne.

## Routage & NAT (à revoir)

- Router central : routage inter-VLAN + NAT sortant (si accès Internet contrôlé).
- Pour la sécurité, faire du **one-way NAT / proxy** s’il faut autoriser certains téléchargements sans exposer les cibles.

## Services essentiels

L’infrastructure de la salle doit intégrer plusieurs services de base pour assurer le bon fonctionnement du lab, la gestion des utilisateurs et la supervision des activités.  
Ces services peuvent être virtualisés (VMs dédiées) ou conteneurisés selon les besoins.

### Réseau et gestion des machines

- **DHCP**  
  Attribution automatique et statiquue d’adresses IP par VLAN.

- **DNS**  
  Résolution interne des noms du lab (ex. `siodhcp`, `siotftp`).

- **TFTP / PXE Boot**  
  Distribution d’images système ou d’outils via boot réseau (installation rapide de VMs, OS de test ou exercices d’exploitation).

- **Scripts**  
  Alias et scripts et automatisés pour efectuer des taches regulieres complexes.

### Authentification et sécurité

- **PKI / Certificats**  
  Gestion des certificats internes pour les services HTTPS et l’authentification des utilisateurs (VPN, AD, Wiki, etc.).

- **Active Directory (Windows + Linux)**  
  Authentification centralisée, gestion des comptes et les stratégies d’accès.

- **RADIUS**  
  Service d’authentification réseau (Wi-Fi, VPN, switch). Interagit avec l’AD

- **OpenVPN**  
  Accès distant sécurisé au lab pour les formateurs et étudiants. Intégré à l’AD/RADIUS pour l’authentification.

### Services pédagogiques et collaboration

- **GitLab**  
  Gestion de projets, héberge des dépôts de script.

- **Wiki**  
  Base de connaissances collaborative (documentation des labs, procédures, etc.).

- **GLPI**  
  Gestion du parc informatique, des tickets de support et du suivi du matériel du lab.

### Supervision et analyse

- **SIEM / ELK (Elasticsearch, Logstash, Kibana)**  
  Analyse et corrélationne des logs (pare-feu, hôtes, IDS/IPS, serveurs). Sert aussi de support à la détection d’incidents.

- **Base de données / SQL**  
  Serveur de données pour les applications internes (GLPI, Wiki, GitLab, etc.) et cible d’exercices pédagogiques (ex. injection SQL, durcissement).

## Stratégie de reset / snapshots (à revoir)

- **script de reset** (Avec Ansible) :

  1. Arrête la VM/Container cible.
  2. Applique un snapshot « clean ».
  3. Redémarre et vérifie l’état (ping/ports).

- Avoir **snapshots fréquents** (clean baseline + points intermédiaires) pour restauration rapide.

## Sécurité et éthique (à revoir)

- **Isolement absolu** : les cibles vulnérables ne doivent jamais pouvoir attaquer l’infrastructure réelle ou Internet (sauf si expressément prévu et contrôlé).
- **Charte d’utilisation** : signature par les apprenants avant accès.
- **Accès contrôlé** : comptes temporaires, logs d’accès, audit des actions sensibles.
- **Procédure d’incident** : documentée dans `SECURITY_POLICY.md`.
- **Normes** : respect du cadre légal, `RGPD` et `Godfrain`.
