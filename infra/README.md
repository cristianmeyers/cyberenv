# Infrastructure de la salle

## Topologie : Tree (arbre)

### Vue d'ensemble

J'ai choisie la topologie en **arbre** (tree) parce-qu'elle permet une hiérarchie claire : un **nœud racine** connecté à des **branches** (VLANs / sous-réseaux) qui desservent des **feuilles** (postes, serveurs, cibles vulnérables). En outre, elle permet de :

- faciliter l’isolation entre groupes d’apprenants ;
- permettre d’appliquer des règles de filtrage par branche ;
- ajouter des nouvelles branches/sous-réseaux si besoin.

---

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

---

## Composants principaux (à revoir)

- **Edge Router / Firewall** : point d’entrée/sortie, NAT, filtrage, VPN d’administration.
- **Switchs d’agrégation** : séparent physiquement/virtuellement les VLANs.
- **Switchs d’accès / Wi-Fi** : postes apprenants, postes formateurs.
- **Jump host / Bastion** : station d’accès centralisée pour les formateurs (accès au lab).
- **Serveurs de services** : DNS interne, DHCP (optionnel), TFTP/FTP, repository d’images.
- **SIEM / Logging** : centralisation des logs (pour apprentissage et audits).
- **Cibles vulnérables** : VMs/containers/OVAs isolés pour exercices.
- **Infrastructure d’orchestration** : hyperviseur / docker / KVM / Proxmox / Vagrant / Terraform / Ansible (configuration).
- **Stockage / Backup** : sauvegardes des images et snapshots (réinitialisation rapide).

---

## Plan d’adressage (exemple)

Utiliser un plan IP privé cohérent — exemple en RFC1918 :

- **VLAN 10 (Serveur)** : `192.168.10.0/24` (DNS, DHCP, TFTP, etc.)
- **VLAN 20 (Backup)** : `192.168.10.0/24` (Backup dns, serveur fichier, etc.)
- **VLAN 30 (Admin)** : `192.168.10.0/24` (host des edutians salle cyber)
- **VLAN 40 (Invités)** : `192.168.10.0/24` (Invités, machines isolées)
- **VLAN 50 (Wi-fi)** : `192.168.10.0/24` (Invités, BYOD, etc.)
- **VLAN 60 (VMs)** : `192.168.10.0/24` (machines vulnérables, isolées)

> Note: Le fichier `dhcp.conf` possede toute la configuration et plan d'addressage du serveur DHCP

---

## VLANs et isolation

- Chaque **niveau / groupe** d’exercices doit avoir son propre VLAN/sous-réseau pour éviter les fuites.
- Appliquer **ACLs** sur le routeur d’agrégation :

  - Management ↔ everything : accès restreint aux administrateurs.
  - Lab VLAN ↔ Services VLAN : accès limité (seulement aux ports nécessaires).
  - Lab VLAN → Internet : bloqué par défaut (autoriser seulement si nécessaire et audité).

- Utiliser des **firewalls logiciels** sur les cibles pour ajouter une couche de protection interne.

---

## Routage & NAT

- Router central : routage inter-VLAN + NAT sortant (si accès Internet contrôlé).
- Pour la sécurité, faire du **one-way NAT / proxy** s’il faut autoriser certains téléchargements sans exposer les cibles.

---

## Services essentiels

- **DNS interne** : résolution des noms de lab (ex. `target1.lab.local`).
- **PKI / certificats** : pour services HTTPS internes si nécessaire.
- **TFTP/FTP/HTTP** : distribution d’images et payloads d’exercice (stockés en read-only pour apprenants).
- **SIEM / ELK** : recueillir logs de pare-feu, hôtes et activités pédagogiques.
- **Snapshot service** : API/script pour réinitialiser les VMs entre sessions.

---

## Stratégie de reset / snapshots

- Fournir un **script de reset** (ou commande Ansible) qui :

  1. Arrête la VM/Container cible.
  2. Applique un snapshot « clean ».
  3. Redémarre et vérifie l’état (ping/ports).

- Avoir **snapshots fréquents** (clean baseline + points intermédiaires) pour restauration rapide.

---

## Sauvegardes et gestion des binaires

- Sauvegarder images et configurations régulièrement (Git pour `.md` et IaC, stockage externe pour OVA/ISO).
- Si tu veux garder seulement `.md` dans le dépôt public : héberge les images ailleurs (ex. GitHub Releases ou stockage S3) et mets les liens dans les `.md`.

---

## Monitoring & journalisation pédagogique

- Conserver des logs pour les exercices (utile en débrief) :

  - logs réseau (NetFlow/sFlow), captures PCAP (optionnel, rotatif), journaux système.

- SIEM pour corréler activités (pratique pédagogique et post-mortem).

---

## Sécurité et éthique

- **Isolement absolu** : les cibles vulnérables ne doivent jamais pouvoir attaquer l’infrastructure réelle ou Internet (sauf si expressément prévu et contrôlé).
- **Charte d’utilisation** : signature par les apprenants avant accès.
- **Accès contrôlé** : comptes temporaires, logs d’accès, audit des actions sensibles.
- **Procédure d’incident** : documentée dans `SECURITY_POLICY.md`.

---

## Matériel / ressources approximatives (guide)

- 1 routeur/firewall (physique ou VM + pfSense/OPNsense)
- 1 switch manageable (VLANs) + câblage
- 1 NAS / serveur de stockage pour images et backups
- Un ou plusieurs serveurs d’hyperviseur (Proxmox, ESXi, KVM) ou une ferme Docker selon ton choix d’orchestration
- Option : Raspberry Pi / mini PC pour jump host ou services légers

---

## Checklist de déploiement (rapide)

- [ ] Définir et documenter le plan IP et VLAN dans `docs/architecture.md`.
- [ ] Mettre en place le routeur/pare-feu et les ACLs de base.
- [ ] Configurer le jump host et les comptes d’administration.
- [ ] Déployer DNS interne et service de distribution d’images.
- [ ] Créer 1-2 scénarios de test et vérifier l’isolation.
- [ ] Implémenter snapshots et tester la procédure de reset.
- [ ] Activer logging centralisé et vérifier réception des logs.
- [ ] Rédiger la charte d’utilisation et la procédure d’incident.

---

## Prochaine étape suggérée (fichier `.md`)

Je peux continuer et générer directement (selon ton souhait) **une section complète `docs/architecture.md`** contenant :

- schéma plus détaillé,
- table d’adressage complète,
- ACLs d’exemple (format human-readable),
- commandes d’exemple pour créer VLANs/switch/bridge (libvirt/docker/iptables/ufw),
- procédure de reset pas à pas.

Souhaites-tu que je **génère ce `docs/architecture.md` maintenant** (avec exemples concrets d’ACL et commandes) ou préfères-tu d’abord un **schéma plus visuel** (ASCII étendu) ?
