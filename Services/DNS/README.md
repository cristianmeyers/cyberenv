# 🌐 DNS — Enregistrements de l'infrastructure `sio.lan`

Tous les enregistrements DNS sont gérés sur **`sioad`** via `samba-tool`. Ce fichier centralise l'ensemble des enregistrements de la zone `sio.lan` et de la zone inverse `10.168.192.in-addr.arpa`.

> **Prérequis :** Exécuter toutes les commandes depuis `sioad` ou avec `-H ldap://sioad` depuis une autre machine.

---

## 📋 Tableau de référence

### Enregistrements A

| Hostname  | FQDN              | Adresse IP       | Rôle                        |
| --------- | ----------------- | ---------------- | --------------------------- |
| `sioad`   | `sioad.sio.lan`   | `192.168.10.4`   | Contrôleur de domaine / DNS |
| `siodhcp` | `siodhcp.sio.lan` | `192.168.10.2`   | Serveur DHCP                |
| `siodb`   | `siodb.sio.lan`   | `192.168.10.5`   | Serveur de bases de données |
| `siolnx`  | `siolnx.sio.lan`  | `192.168.10.6`   | Serveur Linux / Docker      |
| `sionas`  | `sionas.sio.lan`  | `192.168.10.7`   | Serveur NAS                 |
| `siofog`  | `siofog.sio.lan`  | `192.168.10.8`   | Serveur Fog                 |
| `siowin`  | `siowin.sio.lan`  | `192.168.10.9`   | Serveur Windows             |
| `sioback` | `sioback.sio.lan` | `192.168.10.252` | Serveur de sauvegarde       |
| `siovirt` | `siovirt.sio.lan` | `192.168.10.253` | Hyperviseur                 |

### Enregistrements CNAME (services)

| Alias  | Pointe vers      | Service |
| ------ | ---------------- | ------- |
| `wiki` | `siolnx.sio.lan` | Wiki.js |
| `glpi` | `siolnx.sio.lan` | GLPI    |

### Enregistrements PTR (zone inverse)

| Adresse IP       | Pointe vers       |
| ---------------- | ----------------- |
| `192.168.10.2`   | `siodhcp.sio.lan` |
| `192.168.10.4`   | `sioad.sio.lan`   |
| `192.168.10.5`   | `siodb.sio.lan`   |
| `192.168.10.6`   | `siolnx.sio.lan`  |
| `192.168.10.7`   | `sionas.sio.lan`  |
| `192.168.10.8`   | `siofog.sio.lan`  |
| `192.168.10.9`   | `siowin.sio.lan`  |
| `192.168.10.252` | `sioback.sio.lan` |
| `192.168.10.253` | `siovirt.sio.lan` |

---

## 🛠️ Phase 1 : Création de la zone inverse

La zone inverse doit être créée une seule fois avant d'ajouter les enregistrements PTR.

```bash
samba-tool dns zonecreate localhost 10.168.192.in-addr.arpa -U Administrator
```

Vérification :

```bash
samba-tool dns zoneinfo localhost 10.168.192.in-addr.arpa -U Administrator
```

---

## 📝 Phase 2 : Enregistrements A

```bash
# Contrôleur de domaine / DNS
samba-tool dns add localhost sio.lan sioad A 192.168.10.4 -U Administrator

# Serveur DHCP
samba-tool dns add localhost sio.lan siodhcp A 192.168.10.2 -U Administrator

# Serveur de bases de données
samba-tool dns add localhost sio.lan siodb A 192.168.10.5 -U Administrator

# Serveur Linux / Docker
samba-tool dns add localhost sio.lan siolnx A 192.168.10.6 -U Administrator

# Serveur NAS
samba-tool dns add localhost sio.lan sionas A 192.168.10.7 -U Administrator

# Serveur Fog
samba-tool dns add localhost sio.lan siofog A 192.168.10.8 -U Administrator

# Serveur Windows
samba-tool dns add localhost sio.lan siowin A 192.168.10.9 -U Administrator

# Serveur de sauvegarde
samba-tool dns add localhost sio.lan sioback A 192.168.10.252 -U Administrator

# Hyperviseur
samba-tool dns add localhost sio.lan siovirt A 192.168.10.253 -U Administrator
```

---

## 📝 Phase 3 : Enregistrements CNAME (services)

```bash
# Wiki.js
samba-tool dns add localhost sio.lan wiki CNAME siolnx.sio.lan -U Administrator

# GLPI
samba-tool dns add localhost sio.lan glpi CNAME siolnx.sio.lan -U Administrator
```

---

## 📝 Phase 4 : Enregistrements PTR (zone inverse)

```bash
# sioad — 192.168.10.4
samba-tool dns add localhost 10.168.192.in-addr.arpa 4 PTR sioad.sio.lan -U Administrator

# siodhcp — 192.168.10.2
samba-tool dns add localhost 10.168.192.in-addr.arpa 2 PTR siodhcp.sio.lan -U Administrator

# siodb — 192.168.10.5
samba-tool dns add localhost 10.168.192.in-addr.arpa 5 PTR siodb.sio.lan -U Administrator

# siolnx — 192.168.10.6
samba-tool dns add localhost 10.168.192.in-addr.arpa 6 PTR siolnx.sio.lan -U Administrator

# sionas — 192.168.10.7
samba-tool dns add localhost 10.168.192.in-addr.arpa 7 PTR sionas.sio.lan -U Administrator

# siofog — 192.168.10.8
samba-tool dns add localhost 10.168.192.in-addr.arpa 8 PTR siofog.sio.lan -U Administrator

# siowin — 192.168.10.9
samba-tool dns add localhost 10.168.192.in-addr.arpa 9 PTR siowin.sio.lan -U Administrator

# sioback — 192.168.10.252
samba-tool dns add localhost 10.168.192.in-addr.arpa 252 PTR sioback.sio.lan -U Administrator

# siovirt — 192.168.10.253
samba-tool dns add localhost 10.168.192.in-addr.arpa 253 PTR siovirt.sio.lan -U Administrator
```

---

## ✅ Phase 5 : Vérification globale

### Lister tous les enregistrements de la zone directe

```bash
samba-tool dns query localhost sio.lan @ ALL -U Administrator
```

### Lister tous les enregistrements PTR

```bash
samba-tool dns query localhost 10.168.192.in-addr.arpa @ ALL -U Administrator
```

### Vérifier une résolution directe

```bash
nslookup siolnx.sio.lan
nslookup wiki.sio.lan
```

### Vérifier une résolution inverse

```bash
nslookup 192.168.10.6
nslookup 192.168.10.252
```

---

## 🗑️ Supprimer un enregistrement

```bash
# Supprimer un A
samba-tool dns delete localhost sio.lan <hostname> A <ip> -U Administrator

# Supprimer un CNAME
samba-tool dns delete localhost sio.lan <alias> CNAME <cible> -U Administrator

# Supprimer un PTR
samba-tool dns delete localhost 10.168.192.in-addr.arpa <dernier_octet> PTR <fqdn> -U Administrator
```
