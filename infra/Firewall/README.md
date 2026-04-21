# Documentation Pare-feu - Cyberenv

Règles appliquées sur le **Routeur CHR** et les **Switches S1 & S2** - RouterOS **7.20.4**

> ⚠️ Version à vérifier - Document de référence interne

## 1. Vue d'ensemble

| Équipement | Chaînes configurées | Rôle                                           |
| ---------- | ------------------- | ---------------------------------------------- |
| Routeur    | INPUT, FORWARD      | Contrôle accès au routeur + flux inter-VLAN    |
| S1         | INPUT               | Protège l'accès à l'interface de gestion de S1 |
| S2         | INPUT               | Protège l'accès à l'interface de gestion de S2 |

## 2. Matrice des flux autorisés

| Source             | Destination       | Service              | Autorisé | Commentaire                                   |
| ------------------ | ----------------- | -------------------- | :------: | --------------------------------------------- |
| VLAN 30 (ADMIN)    | Tout              | Tout                 |    ✅    | Accès administrateur complet                  |
| VLAN 10 (SERVERS)  | VLAN 10           | Tout                 |    ✅    | Communication inter-Proxmox                   |
| VLAN 10 (SERVERS)  | VLAN 20 (BACKUP)  | Tout                 |    ✅    | Backups Proxmox → PBS / NAS                   |
| VLAN 10 (SERVERS)  | WAN               | HTTP, HTTPS          |    ⏸️    | Mises à jour manuelles (désactivé par défaut) |
| VLAN 40 (WIFI)     | WAN               | Tout                 |    ✅    | Internet uniquement pour les invités          |
| VLAN 40 (WIFI)     | Tout VLAN interne | Tout                 |    ❌    | Isolation totale du Wi-Fi invité              |
| VLAN 20 (BACKUP)   | Tout              | Tout                 |    ❌    | Isolé, accessible uniquement depuis 10/30     |
| Fog (192.168.10.8) | VLAN 30 (ADMIN)   | TFTP, NFS, HTTP      |    ✅    | Déploiement PXE vers PCs (boot uniquement)    |
| Tout               | Tout              | Established, Related |    ✅    | Réponses aux connexions initiées              |

## 3. Routeur - Chaîne INPUT

Protège l'accès au routeur lui-même (Winbox, SSH, DNS, DHCP relay).

### Tableau des règles INPUT

| Ordre | Source          | Service                 |   Action   | Commentaire                        |
| :---: | --------------- | ----------------------- | :--------: | ---------------------------------- |
|   1   | Tous            | Established, Related    | **ACCEPT** | Réponses aux connexions sortantes  |
|   2   | VLAN 30 (ADMIN) | Winbox (8291), SSH (22) | **ACCEPT** | Seul accès gestion autorisé        |
|   3   | Tous            | ICMP                    | **ACCEPT** | Diagnostic réseau                  |
|   4   | Tous            | DNS UDP/TCP (53)        | **ACCEPT** | Résolution DNS via le routeur      |
|   5   | Tous            | DHCP UDP (67)           | **ACCEPT** | Relay DHCP vers Kea (192.168.10.2) |
|   6   | Tous            | Tout                    |  **DROP**  | Blocage de tout le reste           |

### Configuration RouterOS

```bash
/ip firewall filter
add action=accept chain=input connection-state=established,related \
    comment="Accept Established/Related"
add action=accept chain=input src-address=192.168.30.0/24 \
    dst-port=8291,22 protocol=tcp \
    comment="Admin Management (Winbox/SSH)"
add action=accept chain=input protocol=icmp \
    comment="Allow Ping"
add action=accept chain=input dst-port=53 protocol=udp \
    comment="Allow DNS Queries UDP"
add action=accept chain=input dst-port=53 protocol=tcp \
    comment="Allow DNS Queries TCP"
add action=accept chain=input dst-port=67 protocol=udp \
    comment="Allow DHCP Relay Listener"
add action=drop chain=input \
    comment="DROP ALL OTHER TO ROUTER"
```

## 4. Routeur - Chaîne FORWARD

Contrôle les flux entre VLANs et vers Internet.

### Tableau des règles FORWARD

| Ordre | Source            | Destination       | Service              |   Action   | Commentaire                           |
| :---: | ----------------- | ----------------- | -------------------- | :--------: | ------------------------------------- |
|   1   | Tous              | Tous              | Established, Related | **ACCEPT** | Réponses aux connexions initiées      |
|   2   | VLAN 30 (ADMIN)   | Tout              | Tout                 | **ACCEPT** | Accès administrateur complet          |
|   3   | VLAN 10 (SERVERS) | VLAN 10 (SERVERS) | Tout                 | **ACCEPT** | Communication inter-Proxmox           |
|   4   | VLAN 10 (SERVERS) | VLAN 20 (BACKUP)  | Tout                 | **ACCEPT** | Backups vers PBS / NAS                |
|   5   | VLAN 40 (WIFI)    | WAN               | Tout                 | **ACCEPT** | Internet pour les invités Wi-Fi       |
|   6   | Fog (10.8)        | VLAN 30 (ADMIN)   | TFTP, NFS, HTTP      | **ACCEPT** | Déploiement PXE (boot uniquement)     |
|   7   | VLAN 10 (SERVERS) | WAN               | HTTP, HTTPS          | **ACCEPT** | MAJ manuelles VLAN 10 **(désactivé)** |
|   8   | Tous              | Tous              | Tout                 |  **DROP**  | Isolation totale par défaut           |

### Configuration RouterOS

```bash
/ip firewall filter
add action=accept chain=forward connection-state=established,related \
    comment="Accept Established/Related"
add action=accept chain=forward src-address=192.168.30.0/24 \
    comment="VLAN 30 : Admin Full Access"
add action=accept chain=forward src-address=192.168.10.0/24 \
    dst-address=192.168.10.0/24 \
    comment="VLAN 10 : Inter-Proxmox Communication"
add action=accept chain=forward src-address=192.168.10.0/24 \
    dst-address=192.168.20.0/24 \
    comment="VLAN 10 : Backup Access to VLAN 20"
add action=accept chain=forward src-address=192.168.40.0/24 \
    out-interface=WAN \
    comment="VLAN 40 : Internet Only"
add action=accept chain=forward src-address=192.168.10.8 \
    dst-address=192.168.30.0/24 \
    dst-port=69,2049,80 protocol=tcp \
    comment="Fog : PXE Deployment to VLAN 30"
add action=accept chain=forward src-address=192.168.10.0/24 \
    out-interface=WAN dst-port=80,443 protocol=tcp \
    comment="VLAN 10 : Manual Updates (disabled)" disabled=yes
add action=drop chain=forward \
    comment="DROP ALL INTER-VLAN"
```

## 5. NAT (sur le Routeur)

```bash
/ip firewall nat
add action=masquerade chain=srcnat out-interface=WAN \
    src-address=192.168.30.0/24 comment="NAT Admin"
add action=masquerade chain=srcnat out-interface=WAN \
    src-address=192.168.40.0/24 comment="NAT Wi-Fi"
add action=masquerade chain=srcnat out-interface=WAN \
    src-address=192.168.10.0/24 \
    comment="NAT Updates VLAN 10 (Manuel)" disabled=yes
```

## 6. Switch S1 - Chaîne INPUT

Protège l'accès à l'interface de gestion de S1 (IPs `.253`).

### Tableau des règles INPUT - S1

| Ordre | Source          | Service                 |   Action   | Commentaire                  |
| :---: | --------------- | ----------------------- | :--------: | ---------------------------- |
|   1   | Tous            | Established, Related    | **ACCEPT** | Réponses aux connexions      |
|   2   | VLAN 30 (ADMIN) | Winbox (8291), SSH (22) | **ACCEPT** | Seul accès gestion autorisé  |
|   3   | Tous            | ICMP                    | **ACCEPT** | Diagnostic réseau            |
|   4   | Tous            | Tout                    |  **DROP**  | Bloque tout autre accès à S1 |

### Configuration RouterOS - S1

```bash
/ip firewall filter
add action=accept chain=input connection-state=established,related \
    comment="Accept Established/Related"
add action=accept chain=input src-address=192.168.30.0/24 \
    dst-port=8291,22 protocol=tcp \
    comment="Admin Management (Winbox/SSH)"
add action=accept chain=input protocol=icmp \
    comment="Allow Ping"
add action=drop chain=input \
    comment="DROP ALL OTHER TO S1"
```

## 7. Switch S2 - Chaîne INPUT

Identique à S1 - protège l'accès à l'interface de gestion de S2 (IPs `.252`).

### Tableau des règles INPUT - S2

| Ordre | Source          | Service                 |   Action   | Commentaire                  |
| :---: | --------------- | ----------------------- | :--------: | ---------------------------- |
|   1   | Tous            | Established, Related    | **ACCEPT** | Réponses aux connexions      |
|   2   | VLAN 30 (ADMIN) | Winbox (8291), SSH (22) | **ACCEPT** | Seul accès gestion autorisé  |
|   3   | Tous            | ICMP                    | **ACCEPT** | Diagnostic réseau            |
|   4   | Tous            | Tout                    |  **DROP**  | Bloque tout autre accès à S2 |

### Configuration RouterOS - S2

```bash
/ip firewall filter
add action=accept chain=input connection-state=established,related \
    comment="Accept Established/Related"
add action=accept chain=input src-address=192.168.30.0/24 \
    dst-port=8291,22 protocol=tcp \
    comment="Admin Management (Winbox/SSH)"
add action=accept chain=input protocol=icmp \
    comment="Allow Ping"
add action=drop chain=input \
    comment="DROP ALL OTHER TO S2"
```

## 8. Maintenance des règles

### Activer les mises à jour VLAN 10

> ⚠️ À désactiver impérativement après les mises à jour.

```bash
# 1. Activer la règle firewall FORWARD
/ip firewall filter set [find comment="VLAN 10 : Manual Updates (disabled)"] disabled=no

# 2. Activer la règle NAT
/ip firewall nat set [find comment="NAT Updates VLAN 10 (Manuel)"] disabled=no
```

### Désactiver après les mises à jour

```bash
/ip firewall filter set [find comment="VLAN 10 : Manual Updates (disabled)"] disabled=yes
/ip firewall nat set [find comment="NAT Updates VLAN 10 (Manuel)"] disabled=yes
```

## 9. À faire / Améliorations futures

| #   | Tâche                                                             | Priorité |
| --- | ----------------------------------------------------------------- | -------- |
| 1   | Préciser les protocoles NAS (SMB/NFS) et affiner la règle VLAN 20 | Moyenne  |
| 2   | Règles anti-spoofing (vérification interface source)              | Haute    |
| 3   | Drop des paquets invalides (connection-state=invalid)             | Haute    |
| 4   | Filtrage DNS pour VLAN 40 (Pi-hole ou DNS menteur)                | Basse    |
| 5   | VRRP - reconfigurer quand la version RouterOS le supporte         | Basse    |
| 6   | Logs sur les règles DROP pour audit                               | Moyenne  |
