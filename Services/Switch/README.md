# Documentation Complète de la Configuration MikroTik - Switch du Lab (2025)

Ce document décrit **100 %** de la configuration actuelle du **switch MikroTik** du lab, telle qu’elle apparaît dans le fichier `chr-lab-config-switch.rsc` généré le **23 novembre 2025** avec RouterOS **7.20.4**.

## Rôle du Switch dans le Lab

Ce MikroTik fonctionne comme un **switch L2+ avec support VLAN** (modèle moderne RouterOS v7).  
Il reçoit un **lien trunk 802.1Q** depuis le routeur CHR et distribue les 6 VLANs vers les équipements connectés.

## 1. Interfaces Physiques et Renommage

```bash
/interface ethernet
set [ find default-name=ether1 ] name=Trunk
```

- **ether1** → renommé **Trunk** : port connecté au routeur CHR (reçoit toutes les VLANs en tagged)
- **ether2**, **ether3**, … → restent avec leurs noms par défaut pour l’instant (ports d’accès ou futurs accès)

## 2. Bridge Unique avec VLAN Filtering Activé

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes
```

→ Bridge moderne, obligatoire pour une configuration propre avec filtrage VLAN en v7.

## 3. Création des Interfaces VLAN (uniquement pour identification)

```bash
/interface vlan
add name=vlan10 comment=SERVER interface=bridge-vlans vlan-id=10
add name=vlan20 comment=BACKUP interface=bridge-vlans vlan-id=20
add name=vlan30 comment=ADMIN  interface=bridge-vlans vlan-id=30
add name=vlan40 comment=INVITE interface=bridge-vlans vlan-id=40
add name=vlan50 comment=WIFI   interface=bridge-vlans vlan-id=50
add name=vlan60 comment=VMs    interface=bridge-vlans vlan-id=60
```

→ Ces interfaces VLAN **ne servent qu’à l’affichage et à la documentation**.  
Aucune IP n’est attribuée dessus → c’est normal pour un switch L2.

## 4. Configuration du Port Trunk (ether1)

Le port **ether1 (Trunk)** n’est **pas encore ajouté** comme port du bridge dans l’export actuel !  
Il manque donc ces lignes (elles seront probablement ajoutées plus tard) :

```bash
/interface bridge port
add bridge=bridge-vlans interface=Trunk pvid=1   # ou sans pvid si pure trunk

/interface bridge vlan
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=10,20,30,40,50,60
```

**État actuel** : le switch est **presque prêt**, mais le trunk n’est pas encore fonctionnel car ces deux blocs sont absents.

## 5. Clients DHCP (temporaires ou de management)

```bash
/ip dhcp-client
add interface=Trunk
add interface=ether3
```

- Le switch essaie de récupérer une IP sur le lien Trunk (probablement en VLAN native ou VLAN 1)
- ether3 est aussi en client DHCP → utile pour le branchement rapide d’un PC en phase de configuration

## 6. Tableau Récapitulatif des VLANs sur le Switch

| VLAN ID | Nom    | Commentaire | État actuel sur le switch          |
| ------- | ------ | ----------- | ---------------------------------- |
| 10      | vlan10 | SERVER      | Créée (mais pas encore distribuée) |
| 20      | vlan20 | BACKUP      | Créée                              |
| 30      | vlan30 | ADMIN / IT  | Créée                              |
| 40      | vlan40 | INVITE      | Créée                              |
| 50      | vlan50 | WIFI        | Créée                              |
| 60      | vlan60 | VMs         | Créée                              |

## 7. Ce qui Manque pour que le Switch Soit 100 % Opérationnel

Il faut ajouter **obligatoirement** ces commandes :

```bash
# Ajouter le port trunk au bridge
/interface bridge port
add bridge=bridge-vlans interface=Trunk

# Déclarer quelles VLANs passent en tagged sur le trunk
/interface bridge vlan
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=10
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=20
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=30
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=40
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=50
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=60
```

Ou en une seule ligne par VLAN (plus propre) :

```bash
/interface bridge vlan
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=10,20,30,40,50,60
```

## 8. Exemple de Configuration Complète Finale du Switch (à copier-coller)

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes

/interface ethernet
set [find default-name=ether1] name=Trunk

/interface bridge port
add bridge=bridge-vlans interface=Trunk

/interface bridge vlan
add bridge=bridge-vlans tagged=Trunk,bridge-vlans vlan-ids=10,20,30,40,50,60

/interface vlan
add name=vlan10 comment=SERVER interface=bridge-vlans vlan-id=10
add name=vlan20 comment=BACKUP interface=bridge-vlans vlan-id=20
add name=vlan30 comment=ADMIN  interface=bridge-vlans vlan-id=30
add name=vlan40 comment=INVITE interface=bridge-vlans vlan-id=40
add name=vlan50 comment=WIFI   interface=bridge-vlans vlan-id=50
add name=vlan60 comment=VMs    interface=bridge-vlans vlan-id=60
```

Après cela, le switch sera **totalement fonctionnel** comme switch L2 géré avec trunk vers le routeur.

## 9. Sauvegarde de la Configuration

```bash
/system backup save name=switch-lab-20251123.backup
/export hide-sensitive file=switch-lab-config-20251123
```
