# Documentation Complète de la Configuration MikroTik - CHR Lab (2025)

Ce document décrit **l'intégralité** de la configuration actuelle du routeur MikroTik CHR (Cloud Hosted Router) telle qu’elle apparaît dans le fichier `chr-lab-config.rsc` généré le **23 novembre 2025** avec RouterOS **7.20.4**.

## Résumé Général du Design Réseau

- **Type de routeur** : MikroTik CHR (virtualisé)
- **Port WAN** : ether1 → nommé **WAN** (accès Internet)
- **Port Trunk (VLANs)** : ether2 → transporte toutes les VLANs en mode tagged (802.1Q)
- **Port supplémentaire** : ether3 → actuellement utilisé comme client DHCP (probablement pour tests ou management temporaire)
- **6 VLANs configurées** avec routage inter-VLAN activé
- **Bridge avec vlan-filtering=yes** → modèle moderne et sécurisé (recommandé depuis RouterOS v7)
- **Serveur DHCP externe centralisé** sur 192.168.10.2 (probablement un serveur Windows/Linux/Pihole dans la VLAN 10)
- **DNS relay** configuré sur le routeur → tous les clients utilisent le routeur comme DNS
- **Sortie Internet** : uniquement autorisée pour la **VLAN 30 (ADMIN/IT)** via règle NAT masquerade

## 1. Interfaces Physiques et Renommage

```bash
/interface ethernet
set [ find default-name=ether1 ] name=WAN comment="Internet Access"
```

- **ether1** → renommé **WAN** : port connecté à Internet (ou au routeur upstream)
- **ether2** → port trunk vers le switch (ou machine virtuelle/hôte qui gère les VLANs)
- **ether3** → laissé par défaut, utilisé comme client DHCP (accès management temporaire ?)

## 2. Bridges

Deux bridges sont créés :

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes        # Bridge principal avec support VLAN
add name=bridge1                                 # Bridge "legacy" (utilisé uniquement comme parent des interfaces VLAN)
```

> **Note importante** :  
> `bridge1` n’a pas `vlan-filtering=yes` → il sert uniquement de "parent" aux interfaces VLAN.  
> Le vrai filtrage et tagging se fait sur `bridge-vlans`.

## 3. Configuration des VLANs

### Interfaces VLAN créées sur bridge1

| VLAN ID | Nom    | Commentaire | Adresse du routeur |
| ------- | ------ | ----------- | ------------------ |
| 10      | vlan10 | SERVER      | 192.168.10.1/24    |
| 20      | vlan20 | BACKUP      | 192.168.20.1/24    |
| 30      | vlan30 | ADMIN       | 192.168.30.1/24    |
| 40      | vlan40 | INVITE      | 192.168.40.1/24    |
| 50      | vlan50 | WIFI        | 192.168.50.1/24    |
| 60      | vlan60 | VMS         | 192.168.60.1/24    |

### Port membre du bridge VLAN

```bash
/interface bridge port
add bridge=bridge-vlans interface=ether2
```

→ ether2 est le seul port physique membre du bridge VLAN.

### Tagging 802.1Q (Trunk)

Toutes les VLANs passent en **tagged** sur ether2 et sur le bridge lui-même (bonnes pratiques v7) :

```bash
/interface bridge vlan
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=10,20,30,40,50,60
```

→ Cela signifie que le port ether2 est un **port trunk** qui transporte les 6 VLANs.

## 4. Adressage IP (Passerelles par VLAN)

```bash
/ip address
add address=192.168.10.1/24 interface=vlan10 comment=SERVER
add address=192.168.20.1/24 interface=vlan20 comment=BACKUP
add address=192.168.30.1/24 interface=vlan30 comment=ADMIN
add address=192.168.40.1/24 interface=vlan40 comment=INVITE
add address=192.168.50.1/24 interface=vlan50 comment=WIFI
add address=192.168.60.1/24 interface=vlan60 comment=VMS
```

Chaque VLAN a son propre subnet et le routeur est la passerelle par défaut.

## 5. Clients DHCP

```bash
/ip dhcp-client
add interface=WAN           # Récupère l'IP publique ou l'IP du réseau upstream
add interface=ether3        # Probablement pour accès management temporaire
```

## 6. Relais DHCP (DHCP Relay)

Tous les VLANs utilisent un **serveur DHCP centralisé** situé dans la VLAN 10 :

```bash
/ip dhcp-relay
add dhcp-server=192.168.10.2 interface=vlan10 name=relay-vlan10
add dhcp-server=192.168.10.2 interface=vlan20 name=relay-vlan20
add dhcp-server=192.168.10.2 interface=vlan30 name=relay-vlan30
add dhcp-server=192.168.10.2 interface=vlan40 name=relay-vlan40
add dhcp-server=192.168.10.2 interface=vlan50 name=relay-vlan50
add dhcp-server=192.168.10.2 interface=vlan60 name=relay-vlan60
```

→ Le serveur DHCP (192.168.10.2) reçoit les requêtes de tous les VLANs et attribue les IPs en fonction de l’interface source.

## 7. DNS Relay

```bash
/ip dns
set allow-remote-requests=yes servers=192.168.10.2
```

- Le routeur accepte les requêtes DNS de tous les clients internes
- Il forwarde tout vers **192.168.10.2** (probablement Pi-hole, AdGuard, Windows Server DNS, etc.)

## 8. Firewall Filter (Règles actuelles)

Seules **2 règles** sont configurées pour l’instant :

```bash
/ip firewall filter
add action=accept chain=forward dst-port=53 protocol=udp
add action=accept chain=forward dst-port=53 protocol=tcp
```

→ Autorise **uniquement le trafic DNS** (port 53 UDP et TCP) entre les VLANs ou vers Internet.  
**Tout le reste du trafic inter-VLAN et vers Internet est bloqué par défaut** (bonne pratique de sécurité !)

**Conséquence actuelle** :

- Aucune VLAN ne peut accéder à Internet sauf via DNS
- Les VLANs ne peuvent pas communiquer entre elles (sauf DNS vers 192.168.10.2)

## 9. NAT (Sortie Internet)

**Une seule règle NAT** est active :

```bash
/ip firewall nat
add action=masquerade chain=srcnat out-interface=WAN src-address=192.168.30.0/24 comment="Internet VLAN 30"
```

→ **Seule la VLAN 30 (ADMIN/IT)** a actuellement accès à Internet.  
Les autres VLANs n’ont **aucune règle masquerade** → pas d’accès Internet.

## 10. État Actuel du Routage et de la Sécurité

| VLAN            | Accès Inter-VLAN | Accès Internet   | Commentaire              |
| --------------- | ---------------- | ---------------- | ------------------------ |
| VLAN10 (SERVER) | DNS seulement    | Non              | Très sécurisé            |
| VLAN20 (BACKUP) | DNS seulement    | Non              | Très sécurisé            |
| VLAN30 (ADMIN)  | DNS seulement    | Oui (masquerade) | Seule VLAN avec Internet |
| VLAN40 (INVITE) | DNS seulement    | Non              | Bloqué                   |
| VLAN50 (WIFI)   | DNS seulement    | Non              | Bloqué                   |
| VLAN60 (VMS)    | DNS seulement    | Non              | Bloqué                   |

## 11. Ce qu’il manque / À ajouter selon les besoins futurs

Pour rendre le lab pleinement fonctionnel, il faudra probablement ajouter :

1. **Règles firewall forward** pour autoriser le trafic souhaité (ex: VLAN50 → Internet, VLAN60 → serveurs, etc.)
2. **Règles NAT masquerade** supplémentaires pour les autres VLANs si besoin d’Internet
3. **Règles de protection** (anti-spoofing, drop invalid, etc.)
4. **Filtrage input** (protection Winbox/SSH/Web)
5. **Queues** ou **QoS** si limitation de bande passante nécessaire
6. **Wireless** si point d’accès CAPsMAN ou interface WiFi

## 12. Commandes pour Sauvegarder ou Exporter

```bash
/system backup save name=chr-lab-20251123.backup
/export hide-sensitive file=chr-lab-config-20251123
```

Ces fichiers peuvent être téléchargés via Winbox ou FTP.
