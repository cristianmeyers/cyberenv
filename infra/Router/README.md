# Documentation Complète de la Configuration MikroTik - CHR Lab (2025)

Ce document décrit la configuration actuelle du routeur MikroTik CHR (Cloud Hosted Router) telle qu’elle apparaît dans le fichier `chr-lab-config.rsc` généré le **23 novembre 2025** avec RouterOS **7.20.4**.

## Résumé Général du Design Réseau

- **Type de routeur** : MikroTik CHR (virtualisé)
- **Port WAN** : ether1 → nommé **WAN** (accès Internet)
- **Port Access (LAN)** : ether2 → connecté au switch, donne acces a internet

## 1. Interfaces Physiques et Renommage

```bash
/interface ethernet
set [ find default-name=ether1 ] name=WAN comment="Internet Access"
```

- **ether1** → renommé **WAN** : port connecté à Internet (ou au routeur upstream)
- **ether2** → port trunk vers le switch (ou machine virtuelle/hôte qui gère les VLANs)

## 2. Bridge

Un bridges est créé :

```bash
/interface bridge add name=bridge comment="Access"
```

> **Note importante** :  
> `bridge`→ sert uniquement de "parent" aux interfaces LAN.

### On donne une adresse ip au Bridge

```bash
/ip address add address="192.168.10.1" interface="bridge"
```

### On active le client DHCP dans l'interface WAN

```bash
/ip dhcp-client add interface="WAN"
```

## 3. NAT (Sortie Internet)

**Une seule règle NAT** est active :

```bash
/ip firewall nat
add action=masquerade chain=srcnat out-interface=WAN src-address=192.168.10.0/24 comment="Acces Internet"
```

→ **Seule les adresses 172.168.10.0/24 (ADMIN/IT)** a actuellement accès à Internet.

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
