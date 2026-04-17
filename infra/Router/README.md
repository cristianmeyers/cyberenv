# Documentation Complète de la Configuration MikroTik

Ce document décrit la configuration actuelle du routeur MikroTik avec RouterOS **7.20.4**.

## Résumé Général du Design Réseau

- **Type de routeur** : MikroTik (10 ports)
- **Port WAN** : ether1 → nommé **WAN** (accès Internet)
- **Ports Trunks** : ether2, ether3 → nommés **trunk1** et **trunk2**
- **Port Access VLAN 40 (AP)** : ether4 → nommé **access-ap**
- **VLANs Actifs** : 10, 20, 30, 40

## 1. Interfaces Physiques et Renommage

```bash
/interface ethernet
set [ find default-name=ether1 ] name=WAN comment="Internet Access"
set [ find default-name=ether2 ] name=trunk1 comment="Trunk Switch 1"
set [ find default-name=ether3 ] name=trunk2 comment="Trunk Switch 2"
set [ find default-name=ether4 ] name=access-ap comment="Access Port AP VLAN 40"
```

## 2. Bridge et VLANs (Niveau 2)

Un bridge est créé avec le filtrage VLAN activé :

```bash
/interface bridge add name=bridge-vlans vlan-filtering=yes
```

> **Note importante** :  
> `bridge-vlans` sert de commutateur virtuel et de "parent" aux interfaces de routage VLAN.

### Assignation des ports au Bridge

```bash
/interface bridge port
add bridge=bridge-vlans interface=trunk1 frame-types=admit-only-vlan-tagged
add bridge=bridge-vlans interface=trunk2 frame-types=admit-only-vlan-tagged
add bridge=bridge-vlans interface=access-ap pvid=40 frame-types=admit-only-untagged-and-priority-tagged
```

### Configuration de la table de filtrage VLAN

```bash
/interface bridge vlan
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=10
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=20
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=30
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans untagged=access-ap vlan-ids=40
```

## 3. Routage et Adressage IP (Niveau 3)

Création des interfaces virtuelles pour permettre au routeur de communiquer dans chaque VLAN :

```bash
/interface vlan
add interface=bridge-vlans name=vlan10 vlan-id=10
add interface=bridge-vlans name=vlan20 vlan-id=20
add interface=bridge-vlans name=vlan30 vlan-id=30
add interface=bridge-vlans name=vlan40 vlan-id=40
```

### On donne une adresse IP à chaque interface VLAN

```bash
/ip address
add address=192.168.10.1/24 interface=vlan10
add address=192.168.20.1/24 interface=vlan20
add address=192.168.30.1/24 interface=vlan30
add address=192.168.40.1/24 interface=vlan40
```

### On active le client DHCP sur l'interface WAN

```bash
/ip dhcp-client add interface=WAN
```

## 4. NAT (Sortie Internet)

**Une seule règle NAT** est active pour autoriser spécifiquement le réseau ADMIN (VLAN 30) à sortir sur Internet :

```bash
/ip firewall nat
add action=masquerade chain=srcnat out-interface=WAN src-address=192.168.30.0/24 comment="Acces Internet Admin"
```

→ **Seules les adresses 192.168.30.0/24 (ADMIN)** ont actuellement accès à Internet.

## 10. État Actuel du Routage et de la Sécurité

| VLAN             | Accès Inter-VLAN | Accès Internet   | Commentaire             |
| ---------------- | ---------------- | ---------------- | ----------------------- |
| VLAN10 (SERVER)  | DNS seulement    | Non              | Très sécurisé           |
| VLAN20 (BACKUP)  | DNS seulement    | Non              | Très sécurisé           |
| VLAN30 (ADMIN)   | DNS seulement    | Oui (masquerade) | Seul VLAN avec Internet |
| VLAN40 (AP/WIFI) | DNS seulement    | Non              | Bloqué                  |

## 11. Ce qu’il manque / À ajouter selon les besoins futurs

Pour rendre le lab pleinement fonctionnel, il faudra probablement ajouter :

1. **Règles firewall forward** pour autoriser le trafic souhaité (ex: VLAN40 → Internet, ADMIN → serveurs, etc.)
2. **Règles NAT masquerade** supplémentaires pour les autres VLANs si besoin d’Internet (ou remplacer l'IP source par une plage plus large)
3. **Règles de protection** (anti-spoofing, drop invalid, etc.)
4. **Filtrage input** (protection Winbox/SSH/Web limitées au VLAN 30)
5. **Serveurs DHCP** (pour distribuer les IPs automatiquement sur les VLANs 10, 20, 30, 40)
6. **Queues** ou **QoS** si limitation de bande passante nécessaire

## 12. Commandes pour Sauvegarder ou Exporter

```bash
/system backup save name=routeur-lab-vlan-config.backup
/export hide-sensitive file=routeur-lab-vlan-export
```
