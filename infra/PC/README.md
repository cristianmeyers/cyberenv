# Configuration BIOS Dell Optiplex — Boot PXE FOG

Ce document décrit les paramètres BIOS à configurer sur les Dell Optiplex pour permettre le boot PXE et le déploiement d'images via FOG Project.

---

## Boot Sequence

| Paramètre        | Valeur   |
| ---------------- | -------- |
| Boot List Option | **UEFI** |

---

## Advanced Boot Options

| Paramètre                 | Valeur                                                   |
| ------------------------- | -------------------------------------------------------- |
| Enable Legacy Option ROMs | **Activé** (si nécessaire pour compatibilité matérielle) |

---

## System Configuration

| Paramètre          | Valeur               |
| ------------------ | -------------------- |
| Integrated NIC     | **Enabled with PXE** |
| UEFI Network Stack | **Enabled**          |
| SATA Operation     | **AHCI**             |

> ⚠️ Ne pas laisser en mode RAID — FOG (noyau Linux) est incompatible avec le mode RAID Intel sur les Optiplex.

---

## Secure Boot

| Paramètre   | Valeur  |
| ----------- | ------- |
| Secure Boot | **Off** |

> ⚠️ iPXE standard fourni par FOG n'est pas signé — Secure Boot doit être désactivé.

---

## Power Management

| Paramètre   | Valeur                |
| ----------- | --------------------- |
| Wake on LAN | **LAN with PXE Boot** |

> Permet d'allumer les machines à distance depuis l'interface FOG (Wake on LAN) et de lancer automatiquement un déploiement PXE.

---

## Ordre de boot recommandé

1. Network (PXE)
2. Disque interne (SSD/HDD)
3. USB (optionnel)

---

## Notes

- Ces paramètres ont été validés sur **Dell Optiplex 7060 Micro**.
- Serveur FOG : `192.168.10.8` (siofog.sio.lan)
- DHCP : Kea sur `siodhcp` avec détection automatique UEFI/BIOS Legacy
- Pour accéder au BIOS : touche **F2** au démarrage
- Pour accéder au menu de boot : touche **F12** au démarrage
