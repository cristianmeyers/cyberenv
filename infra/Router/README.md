# Documentation Routeur MikroTik - Cyberenv

Configuration **Routeur CHR** - RouterOS **7.20.4**

> ⚠️ Version à vérifier - Document de référence interne

## 1. Architecture

- **Routeur** → Internet + routage inter-VLAN en temps normal (master VRRP, priority 100)
- **IP virtuelle VRRP** → `.1` sur les VLANs 10, 20, 30 (passerelle des équipements filaires)
- **IPs réelles** → `.254` sur chaque VLAN
- **VLAN 40 (Wi-Fi)** → pas de VRRP, l'AP est branché sur le routeur directement
- **RSTP** → priority 32768 (ne doit pas être root bridge)

## 2. Plan d'Adressage

| Équipement        | VLAN 10        | VLAN 20        | VLAN 30        | VLAN 40        |
| ----------------- | -------------- | -------------- | -------------- | -------------- |
| IP virtuelle VRRP | 192.168.10.1   | 192.168.20.1   | 192.168.30.1   | -              |
| Routeur (master)  | 192.168.10.254 | 192.168.20.254 | 192.168.30.254 | 192.168.40.254 |
| S1 (backup 1)     | 192.168.10.253 | 192.168.20.253 | 192.168.30.253 | 192.168.40.253 |
| S2 (backup 2)     | 192.168.10.252 | 192.168.20.252 | 192.168.30.252 | 192.168.40.252 |

## 3. Résumé Général du Design Réseau

- **Type de routeur** : MikroTik CHR (10 ports)
- **Port WAN** : ether1 → nommé **WAN** (accès Internet)
- **Ports Trunks** : ether2, ether3 → nommés **trunk1** et **trunk2**
- **Port Access VLAN 40 (AP)** : ether4 → nommé **access-ap**
- **VLANs Actifs** : 10, 20, 30, 40

## 4. Interfaces Physiques et Renommage

```bash
/interface ethernet
set [ find default-name=ether1 ] name=WAN       comment="Internet Access"
set [ find default-name=ether2 ] name=trunk1    comment="Trunk Switch 1"
set [ find default-name=ether3 ] name=trunk2    comment="Trunk Switch 2"
set [ find default-name=ether4 ] name=access-ap comment="Access Port AP VLAN 40"
```

## 5. Bridge et VLANs (Niveau 2)

#### Bridge avec VLAN filtering et RSTP

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes protocol-mode=rstp priority=32768
```

> Le routeur a la priorité RSTP la plus haute - il ne doit jamais être root bridge.

#### Assignation des ports au bridge

```bash
/interface bridge port
add bridge=bridge-vlans interface=trunk1    frame-types=admit-only-vlan-tagged
add bridge=bridge-vlans interface=trunk2    frame-types=admit-only-vlan-tagged
add bridge=bridge-vlans interface=access-ap pvid=40 frame-types=admit-only-untagged-and-priority-tagged
```

#### Configuration de la table de filtrage VLAN

```bash
/interface bridge vlan
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=10
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=20
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=30
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans untagged=access-ap vlan-ids=40
```

## 6. Routage et Adressage IP (Niveau 3)

#### Interfaces VLAN

```bash
/interface vlan
add interface=bridge-vlans name=vlan10 vlan-id=10
add interface=bridge-vlans name=vlan20 vlan-id=20
add interface=bridge-vlans name=vlan30 vlan-id=30
add interface=bridge-vlans name=vlan40 vlan-id=40
```

#### Adresses IP réelles

```bash
/ip address
add address=192.168.10.254/24 interface=vlan10
add address=192.168.20.254/24 interface=vlan20
add address=192.168.30.254/24 interface=vlan30
add address=192.168.40.254/24 interface=vlan40
```

#### Client DHCP sur WAN

```bash
/ip dhcp-client add interface=WAN
```

## 7. VRRP (Master, priority 100)

> VRRP uniquement sur les VLANs filaires 10, 20, 30. Le VLAN 40 (Wi-Fi) n'en a pas besoin car l'AP est branché directement sur le routeur - si le routeur tombe, le Wi-Fi tombe aussi.

```bash
/interface vrrp
add name=vrrp-vlan10 interface=vlan10 vrid=10 priority=100 authentication=ah password=secret
add name=vrrp-vlan20 interface=vlan20 vrid=20 priority=100 authentication=ah password=secret
add name=vrrp-vlan30 interface=vlan30 vrid=30 priority=100 authentication=ah password=secret
```

## 8. NAT (Sortie Internet)

Une seule règle NAT active - seul le VLAN 30 (ADMIN) a accès à Internet :

```bash
/ip firewall nat
add action=masquerade chain=srcnat out-interface=WAN src-address=192.168.30.0/24 comment="Acces Internet Admin"
```

## 9. État Actuel du Routage et de la Sécurité

| VLAN             | Accès Inter-VLAN | Accès Internet   | Commentaire                   |
| ---------------- | ---------------- | ---------------- | ----------------------------- |
| VLAN10 (SERVER)  | DNS seulement    | Non              | Très sécurisé                 |
| VLAN20 (BACKUP)  | DNS seulement    | Non              | Très sécurisé                 |
| VLAN30 (ADMIN)   | DNS seulement    | Oui (masquerade) | Seul VLAN avec Internet       |
| VLAN40 (AP/WIFI) | DNS seulement    | Non              | Passerelle routeur uniquement |

## 10. Ce qu'il manque / À ajouter selon les besoins futurs

1. **Règles firewall forward** pour autoriser le trafic souhaité (ex: VLAN40 → Internet, ADMIN → serveurs)
2. **Règles NAT masquerade** supplémentaires pour les autres VLANs si besoin d'Internet
3. **Règles de protection** (anti-spoofing, drop invalid, etc.)
4. **Filtrage input** (protection Winbox/SSH/Web limitées au VLAN 30)
5. **Serveurs DHCP** (pour distribuer les IPs automatiquement sur les VLANs 10, 20, 30, 40)
6. **Queues / QoS** si limitation de bande passante nécessaire

## 11. Sauvegarde de la Configuration

```bash
/system backup save name=routeur-lab-vlan-config.backup
/export hide-sensitive file=routeur-lab-vlan-export
```
