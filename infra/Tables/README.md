# Schema des connexions switches comprends les vlans et les connextions entre les equipements physiques

## VLANs

- **VLAN 10 :** Seveurs
- **VLAN 20 :** Backup
- **VLAN 30 :** Administration
- **VLAN 40 :** Wi-Fi

### Switch S1

- **Emplacement :** A005
- **Modèle :** Mikrotik
- **Nombre de ports :** 24
- **VLANs :**

```md
| Port | VLAN  | Service               |
| ---- | ----- | --------------------- |
| 1    | Trunk | Router                |
| 2    | Trunk | Int-Vlan Switch 2     |
| 3    | 10    | Proxmox 1             |
| 4    | 10    | Proxmox 2             |
| 5    | 10    | Proxmox 3             |
| 6    | 20    | Proxmox Backup Server |
| 7    | 20    | NAS                   |
```

### Switch S2

- **Emplacement :** Baie
- **Modèle :** Mikrotik
- **Nombre de ports :** 24
- **VLANs :**

```md
| Port | VLAN  | Service           |
| ---- | ----- | ----------------- |
| 1    | Trunk | Router            |
| 2    | Trunk | Int-Vlan switch 1 |
| 3    | 30    | PC                |
| 4    | 30    | PC                |
| 5    | 30    | PC                |
| 6    | 30    | PC                |
| 7    | 30    | PC                |
```

### Router (R)

- **Emplacement :** Baie
- **Modèle :** Mikrotik
- **Nombre de ports :** 10
- **VLANs :** 10, 20, 30, 40

```md
| Port | VLAN  | Service  |
| ---- | ----- | -------- |
| 1    | WAN   |          |
| 2    | Trunk | Switch 1 |
| 3    | Trunk | Switch 2 |
| 4    | 40    | AP       |
| 5    | —     |          |
| 6    | —     |          |
```

### Panel / Bridge (Baie de Brassage)

```md
| Port |                VLAN                |
| ---- | :--------------------------------: |
| J1   |                WAN                 |
| 1    |       Acces Point -> Router        |
| 2    |                 PC                 |
| 3    |                 PC                 |
| 4    |                 PC                 |
| 5    | Switch 1 <-- Int Vlan --> Switch 2 |
| 6    |                 PC                 |
| 7    |                HUB                 |
| 8    |        Switch 1 --> Router         |
| 55   |                 /                  |
| 56   |                 /                  |
```
