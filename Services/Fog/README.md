# 🖥️ FOG Project — Déploiement d'images réseau (PXE)

## Contexte

Dans le cadre du lab **cyberenv**, FOG Project est utilisé pour automatiser le déploiement des postes de travail (Dell Optiplex) via PXE. Il permet de capturer une image "master" d'un poste configuré (ex: Kali Linux Everything) et de la redéployer sur l'ensemble du parc en quelques minutes, sans intervention manuelle sur chaque machine.

---

## Infrastructure

| Composant       | Valeur                               |
| --------------- | ------------------------------------ |
| Serveur FOG     | `siofog.sio.lan` — `192.168.10.8`    |
| OS serveur      | Ubuntu Server 22.04 LTS              |
| DHCP            | Kea sur `siodhcp`                    |
| Domaine         | `sio.lan`                            |
| Stockage images | `/images` (disque dédié)             |
| Interface web   | `http://192.168.10.8/fog/management` |

---

## Architecture PXE

```
[Dell Optiplex]
      │
      │  DHCP Discover (PXE)
      ▼
[siodhcp — Kea DHCP]
      │  IP + next-server: 192.168.10.8
      │  boot-file: ipxe.efi (UEFI) / undionly.kpxe (BIOS)
      ▼
[siofog — TFTP]
      │  Téléchargement iPXE
      ▼
[siofog — FOG Web]
      │  Menu PXE / Tâche assignée
      ▼
  Capture ou Déploiement image
```

---

## Installation FOG

```bash
# Prérequis
sudo apt update && sudo apt upgrade -y
sudo apt install -y git

# Cloner et installer
cd /opt
sudo git clone https://github.com/FOGProject/fogproject.git
cd fogproject/bin
sudo ./installfog.sh
```

### Réponses à l'installateur

| Question               | Réponse                                   |
| ---------------------- | ----------------------------------------- |
| Type de Linux          | `2` (Debian/Ubuntu)                       |
| Type d'installation    | `N` (Normal Server)                       |
| Interface réseau       | `ens18`                                   |
| Router DHCP            | `n` (Kea gère le DHCP)                    |
| DNS via DHCP           | `n`                                       |
| FOG comme serveur DHCP | `n`                                       |
| Packs de langues       | `n`                                       |
| HTTPS                  | `n` (à configurer après avec PKI interne) |

Finaliser l'installation via le navigateur :

```
http://192.168.10.8/fog/management
→ Cliquer "Install/Update Now"
→ Revenir au terminal et appuyer sur Entrée
```

---

## Configuration Kea DHCP — PXE

Le fichier `/etc/kea/kea-dhcp4.conf` doit inclure les éléments suivants pour le boot PXE :

```json
"client-classes": [
  {
    "name": "UEFI-x64",
    "test": "substring(option[60].text, 0, 9) == 'PXEClient' and (option[93].hex == 0x0007 or option[93].hex == 0x0009)",
    "option-data": [
      { "name": "boot-file-name", "data": "ipxe.efi" }
    ]
  },
  {
    "name": "BIOS-Legacy",
    "test": "substring(option[60].text, 0, 9) == 'PXEClient' and option[93].hex == 0x0000",
    "option-data": [
      { "name": "boot-file-name", "data": "undionly.kpxe" }
    ]
  },
  {
    "name": "Catch-All-PXE",
    "test": "substring(option[60].text, 0, 9) == 'PXEClient'",
    "option-data": [
      { "name": "boot-file-name", "data": "ipxe.efi" }
    ]
  }
],
"subnet4": [
  {
    "next-server": "192.168.10.8",
    "option-data": [
      { "name": "tftp-server-name", "data": "192.168.10.8" }
    ]
  }
]
```

> ⚠️ Le champ `next-server` est obligatoire — les BIOS Dell lisent le champ `siaddr` du header DHCP, pas seulement l'option 66.

Valider et redémarrer :

```bash
sudo kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
sudo systemctl restart kea-dhcp4-server.service
```

---

## Configuration BIOS Dell Optiplex

Voir [BIOS-Dell-PXE.md](./BIOS-Dell-PXE.md) pour la procédure complète.

Points critiques :

| Paramètre          | Valeur              |
| ------------------ | ------------------- |
| Boot List Option   | UEFI                |
| Integrated NIC     | Enabled with PXE    |
| UEFI Network Stack | Enabled             |
| SATA Operation     | **AHCI** (pas RAID) |
| Secure Boot        | **Off**             |
| Wake on LAN        | LAN with PXE Boot   |

---

## Workflow Capture / Déploiement

### Préparer le poste master

```bash
# Nettoyer avant capture
sudo apt autoremove -y && sudo apt clean
sudo rm -rf /tmp/*

# Réinitialiser le machine-id (évite les conflits réseau sur les clones)
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
```

### Capturer une image

1. Créer l'image dans FOG Web → **Images → Create New Image**

| Champ           | Valeur                  |
| --------------- | ----------------------- |
| Image Name      | `kali-everything`       |
| Image Type      | Single Disk - Resizable |
| OS              | Linux                   |
| Partition Style | GPT                     |
| Image Manager   | Partclone Zstd          |
| Compression     | 6                       |

2. Associer l'image au host → **Hosts → [host] → Host Image**
3. Lancer la tâche → **Hosts → [host] → Basic Tasks → Capture**
4. Booter le poste en PXE — la capture démarre automatiquement

### Déployer une image

1. Booter la machine cible en PXE → **Full Host Registration and Inventory**
2. Dans FOG Web → **Hosts → [host] → Host Image** → sélectionner l'image
3. **Basic Tasks → Deploy → Task**
4. Booter en PXE — le déploiement démarre automatiquement

### Déploiement multicast (plusieurs machines simultanément)

Pour déployer sur 10+ machines en même temps :

1. Créer un groupe → **Groups → Create New Group**
2. Ajouter les hosts au groupe
3. **Groups → [groupe] → Basic Tasks → Multicast**

---

## Images disponibles

| Nom               | OS                | Type                       | Taille |
| ----------------- | ----------------- | -------------------------- | ------ |
| `kali-everything` | Kali Linux (full) | Single Disk Resizable ZSTD | ~45 Go |

---

## Snapins (post-déploiement)

Les snapins permettent d'exécuter automatiquement des scripts après déploiement (jonction AD, changement hostname, installation logiciels…).

Le **FOG Client** doit être installé sur l'image master pour que les snapins fonctionnent.

```bash
# Installation FOG Client sur le poste master (avant capture)
wget https://github.com/FOGProject/fog-client/releases/latest/download/SmartInstaller
sudo bash SmartInstaller
```

---

## Dépannage

### La machine n'obtient pas d'IP

- Vérifier que Kea tourne : `sudo systemctl status kea-dhcp4-server`
- Vérifier les logs : `sudo journalctl -fu kea-dhcp4-server`

### La machine obtient une IP mais ne boote pas

- Vérifier TFTP : `sudo systemctl status tftpd-hpa`
- Vérifier les fichiers : `ls /tftpboot/` (doit contenir `ipxe.efi` et `undionly.kpxe`)
- Tester TFTP depuis le réseau : `tftp 192.168.10.8 -c get undionly.kpxe`
- Vérifier `next-server` dans Kea

### Menu FOG ne s'affiche pas

- Vérifier Secure Boot désactivé dans le BIOS
- Vérifier SATA en mode AHCI (pas RAID)
- Vérifier NIC en mode "Enabled with PXE"

### Surveiller en temps réel

```bash
# Trafic TFTP
sudo tcpdump -i ens18 udp port 69

# Logs DHCP
sudo journalctl -fu kea-dhcp4-server

# Logs Apache FOG
sudo tail -f /var/log/apache2/access.log
```

---

## Liens utiles

- [FOG Project Documentation](https://docs.fogproject.org)
- [FOG Project Wiki](https://wiki.fogproject.org)
- [Kea DHCP Documentation](https://kea.readthedocs.io)
