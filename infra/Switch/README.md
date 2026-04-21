# Documentation Switch MikroTik - Cyberenv

Configuration **Switch S1 & S2** - RouterOS **7.20.4**

> ⚠️ Version à vérifier - Document de référence interne

## 1. Architecture

- **Routeur** → Internet + routage inter-VLAN en temps normal (master VRRP, priority 100)
- **S1 & S2** → routage inter-VLAN de secours via VRRP (`.253` et `.252`)
- **IP virtuelle VRRP** → `.1` sur les VLANs 10, 20, 30 (passerelle des équipements filaires)
- **VLAN 40 (Wi-Fi)** → pas de VRRP, IPs de gestion uniquement
- **Lien trunk S1↔S2** → continuité L2/L3 entre les deux switches
- **RSTP** → protection contre les boucles L2

## 2. Plan d'Adressage

| Équipement        | VLAN 10        | VLAN 20        | VLAN 30        | VLAN 40        |
| ----------------- | -------------- | -------------- | -------------- | -------------- |
| IP virtuelle VRRP | 192.168.10.1   | 192.168.20.1   | 192.168.30.1   | —              |
| Routeur (master)  | 192.168.10.254 | 192.168.20.254 | 192.168.30.254 | 192.168.40.254 |
| S1 (backup 1)     | 192.168.10.253 | 192.168.20.253 | 192.168.30.253 | 192.168.40.253 |
| S2 (backup 2)     | 192.168.10.252 | 192.168.20.252 | 192.168.30.252 | 192.168.40.252 |

## 3. Schéma des Connexions Physiques

```
  [Internet/WAN]
       |
  [Router R] ─── ether2 ──► S1 (A005)
  (Baie)     ─── ether3 ──► S2 (Baie)
             ─── ether4 ──► AP Wi-Fi (VLAN 40)

  [S1] ─── ether2 ◄──Trunk──► ether2 [S2]
   |                                    |
  ether3 Proxmox 1  (VLAN 10)       ether3 PC (VLAN 30)
  ether4 Proxmox 2  (VLAN 10)       ether4 PC (VLAN 30)
  ether5 Proxmox 3  (VLAN 10)       ether5 PC (VLAN 30)
  ether6 PBS        (VLAN 20)       ether6 PC (VLAN 30)
  ether7 NAS        (VLAN 20)       ether7 PC (VLAN 30)
```

## 4. Tableau des VLANs

| VLAN ID | Nom            | Équipements                      |
| ------- | -------------- | -------------------------------- |
| 10      | Serveurs       | Proxmox 1, Proxmox 2, Proxmox 3  |
| 20      | Backup         | Proxmox Backup Server, NAS       |
| 30      | Administration | PCs (A005)                       |
| 40      | Wi-Fi          | Access Point (Router uniquement) |

## 5. Switch S1

**Emplacement :** A005 | **Modèle :** MikroTik | **Ports :** 24

### 5.1 Affectation des ports

| Port      | VLAN  | Service                                     |
| --------- | ----- | ------------------------------------------- |
| ether1    | Trunk | Uplink → Router CHR (tagged 10,20,30,40)    |
| ether2    | Trunk | Inter-VLAN ↔ Switch S2 (tagged 10,20,30,40) |
| ether3    | 10    | Proxmox 1                                   |
| ether4    | 10    | Proxmox 2                                   |
| ether5    | 10    | Proxmox 3                                   |
| ether6    | 20    | Proxmox Backup Server                       |
| ether7    | 20    | NAS                                         |
| ether8–24 | —     | (Non attribués)                             |

### 5.2 Configuration RouterOS

#### Renommage des interfaces

```bash
/interface ethernet
set [ find default-name=ether1 ] name=trunk1
set [ find default-name=ether2 ] name=trunk2
```

#### Bridge avec VLAN filtering et RSTP

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes protocol-mode=rstp priority=4096
```

> S1 est le **root bridge** (priorité STP la plus haute).

#### Interfaces VLAN

```bash
/interface vlan
add name=vlan10 comment=SERVERS interface=bridge-vlans vlan-id=10
add name=vlan20 comment=BACKUP  interface=bridge-vlans vlan-id=20
add name=vlan30 comment=ADMIN   interface=bridge-vlans vlan-id=30
add name=vlan40 comment=WIFI    interface=bridge-vlans vlan-id=40
```

#### Ajout des ports au bridge

```bash
/interface bridge port
add bridge=bridge-vlans interface=trunk1 pvid=1
add bridge=bridge-vlans interface=trunk2 pvid=1
add bridge=bridge-vlans interface=ether3 pvid=10
add bridge=bridge-vlans interface=ether4 pvid=10
add bridge=bridge-vlans interface=ether5 pvid=10
add bridge=bridge-vlans interface=ether6 pvid=20
add bridge=bridge-vlans interface=ether7 pvid=20
```

#### VLAN tagging / untagging

```bash
/interface bridge vlan
# Trunk ports : tagged sur tous les VLANs
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=10,20,30,40
# Ports d'accès VLAN 10 (Proxmox) : untagged
add bridge=bridge-vlans untagged=ether3,ether4,ether5 vlan-ids=10
# Ports d'accès VLAN 20 (Backup) : untagged
add bridge=bridge-vlans untagged=ether6,ether7 vlan-ids=20
```

#### Adresses IP

```bash
/ip address
add address=192.168.10.253/24 interface=vlan10 comment=SERVERS
add address=192.168.20.253/24 interface=vlan20 comment=BACKUP
add address=192.168.30.253/24 interface=vlan30 comment=ADMIN
add address=192.168.40.253/24 interface=vlan40 comment=WIFI
```

#### VRRP (backup priority 90 — VLANs filaires uniquement)

```bash
/interface vrrp
add name=vrrp-vlan10 interface=vlan10 vrid=10 priority=90 authentication=ah password=secret
add name=vrrp-vlan20 interface=vlan20 vrid=20 priority=90 authentication=ah password=secret
add name=vrrp-vlan30 interface=vlan30 vrid=30 priority=90 authentication=ah password=secret
```

## 6. Switch S2

**Emplacement :** Baie | **Modèle :** MikroTik | **Ports :** 24

### 6.1 Affectation des ports

| Port      | VLAN  | Service                                     |
| --------- | ----- | ------------------------------------------- |
| ether1    | Trunk | Uplink → Router CHR (tagged 10,20,30,40)    |
| ether2    | Trunk | Inter-VLAN ↔ Switch S1 (tagged 10,20,30,40) |
| ether3    | 30    | PC Administration                           |
| ether4    | 30    | PC Administration                           |
| ether5    | 30    | PC Administration                           |
| ether6    | 30    | PC Administration                           |
| ether7    | 30    | PC Administration                           |
| ether8–24 | —     | (Non attribués)                             |

### 6.2 Configuration RouterOS

#### Renommage des interfaces

```bash
/interface ethernet
set [ find default-name=ether1 ] name=trunk1
set [ find default-name=ether2 ] name=trunk2
```

#### Bridge avec VLAN filtering et RSTP

```bash
/interface bridge
add name=bridge-vlans vlan-filtering=yes protocol-mode=rstp priority=8192
```

> S2 est le **backup root bridge** (priorité secondaire).

#### Interfaces VLAN

```bash
/interface vlan
add name=vlan10 comment=SERVERS interface=bridge-vlans vlan-id=10
add name=vlan20 comment=BACKUP  interface=bridge-vlans vlan-id=20
add name=vlan30 comment=ADMIN   interface=bridge-vlans vlan-id=30
add name=vlan40 comment=WIFI    interface=bridge-vlans vlan-id=40
```

#### Ajout des ports au bridge

```bash
/interface bridge port
add bridge=bridge-vlans interface=trunk1 pvid=1
add bridge=bridge-vlans interface=trunk2 pvid=1
add bridge=bridge-vlans interface=ether3 pvid=30
add bridge=bridge-vlans interface=ether4 pvid=30
add bridge=bridge-vlans interface=ether5 pvid=30
add bridge=bridge-vlans interface=ether6 pvid=30
add bridge=bridge-vlans interface=ether7 pvid=30
```

#### VLAN tagging / untagging

```bash
/interface bridge vlan
# Trunk ports : tagged sur tous les VLANs
add bridge=bridge-vlans tagged=trunk1,trunk2,bridge-vlans vlan-ids=10,20,30,40
# Ports d'accès VLAN 30 (Admin) : untagged
add bridge=bridge-vlans untagged=ether3,ether4,ether5,ether6,ether7 vlan-ids=30
```

#### Adresses IP

```bash
/ip address
add address=192.168.10.252/24 interface=vlan10 comment=SERVERS
add address=192.168.20.252/24 interface=vlan20 comment=BACKUP
add address=192.168.30.252/24 interface=vlan30 comment=ADMIN
add address=192.168.40.252/24 interface=vlan40 comment=WIFI
```

#### VRRP (backup priority 80 — VLANs filaires uniquement)

```bash
/interface vrrp
add name=vrrp-vlan10 interface=vlan10 vrid=10 priority=80 authentication=ah password=secret
add name=vrrp-vlan20 interface=vlan20 vrid=20 priority=80 authentication=ah password=secret
add name=vrrp-vlan30 interface=vlan30 vrid=30 priority=80 authentication=ah password=secret
```

## 7. Router (R) — Ports de référence

**Emplacement :** Baie | **Modèle :** MikroTik | **Ports :** 10

| Port   | VLAN  | Service                                   |
| ------ | ----- | ----------------------------------------- |
| ether1 | WAN   | Accès Internet                            |
| ether2 | Trunk | Downlink → Switch S1 (tagged 10,20,30,40) |
| ether3 | Trunk | Downlink → Switch S2 (tagged 10,20,30,40) |
| ether4 | 40    | Access Point Wi-Fi                        |
| ether5 | —     | (Libre)                                   |
| ether6 | —     | (Libre)                                   |

## 8. Baie de Brassage (Patch Panel)

| Port | Connexion                              |
| ---- | -------------------------------------- |
| J1   | WAN (arrivée opérateur)                |
| 1    | Access Point → Router ether4 (VLAN 40) |
| 2    | PC → Switch S2                         |
| 3    | PC → Switch S2                         |
| 4    | PC → Switch S2                         |
| 5    | Switch S1 ↔ Switch S2 (trunk)          |
| 6    | PC → Switch S2                         |
| 7    | HUB                                    |
| 8    | Switch S1 → Router ether2 (trunk)      |
| 55   | /                                      |
| 56   | /                                      |

## 9. Sauvegarde de la Configuration

À exécuter sur **chaque switch** après toute modification :

```bash
# Sauvegarde binaire (restauration complète)
/system backup save name=switch-lab-20251123.backup

# Export texte (lecture / audit)
/export hide-sensitive file=switch-lab-config-20251123
```

> Nommer les fichiers avec la date du jour et les stocker sur un serveur de fichiers.
