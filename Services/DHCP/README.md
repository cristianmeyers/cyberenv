# DHCP

Pour le service DHCP j'ai choisi un **Ubuntu Live server 24.04 LTS** comme serveur principal puis `isc-dhcp-server` comme service dhcp. Ci-dessous il y aura la configuration en partant de zéro.

## Interfaces & Réseaux

Faut determiner d'abord l'interface souhaitée, celle qui recevra les requetes ARP:

```bash
    ip a
```

devra montrer :

![enp0s3 ou nom similaire](../../IMG/ipa_dhcp.png)

avec cette information on peut deternminer le nom de ml'interface, son etat : `UP` ou `Down`, ainsi que son addresse MAC et **possible addresse IP**, dans ce cas :

- **Nom** : `enp0s8`
- **MAC** : `08:00:27:36:7f:93`
- **Etat** : `Down`
- **IP** : vide

Maintenant faut conecter le seveur a internet via cette interface, je prend enp0s3 comme exemple. pour cela, deux moyen, activer le dhcp, ou utiliser une addresse physique. Dans notre cas, l'option 1 es plus adapté.

```bash
sudo nano /etc/netplan/00-installer-config.yaml

```

Et remplir le fichier avec

```yaml
network:
  renderer: networkd
  ethernets:
    enp0s8: # interface en question
      dhcp4: true # active la connexion par dhcp
```

> Attention à l'indentation !!

On test l'application des configs pour eviter une deconnexion du serveur si on est connecté par SSH, et si pas d'erreur, on **applique**. puis on active l'interface.

```bash
sudo netplan try  # pour tester si pas d'erreur du fichier netplan
sudo netplan apply  # appliquer
sudo ip link set enp0s8 up  # attention au nom de l'interface !!
```

Plus qu'a vérifier avec `ip a` pour confirmer l'existance d'une addresses IP, et `ping 8.8.8.8` pour tester la connexion internet

---

## Services

On va installer `isc-dhcp-server`, le configurer pour **écouter sur l’interface trunk + VLANs**, puis le lancer et le surveiller.

```bash
# Mise à jour + installation
sudo apt update -y
sudo apt install isc-dhcp-server -y
```

**Configuration des interfaces d’écoute**

```bash
nano /etc/default/isc-dhcp-server
```

Modifie la ligne pour écouter sur l’interface physique **ET** les sous-interfaces VLAN :

```bash
INTERFACESv4="enp0s3"
```

> Pourquoi ? <br> > **enp0s3** → écoute toutes les requetes de cette interface

```bash
sudo systemctl start isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl status isc-dhcp-server
```

### Étape 1 : Donner une addresse ip à l'interface

```bash
sudo ip addr add 192.168.10.2/24 dev enp0s3
```

### Étape 2 : Vérifier

```bash
ip -br a | grep enp0s3
```

### Étape 3 : Rendre l'IP persistante (après reboot)

```bash
sudo nano /etc/netplan/01-vlans.yaml
```

Remplir le fichier avec:

```bash
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: no
      adresses: [192.168.10.2/24]
      routes:
        - to : default
          via : 192.168.10.254
```

> \*\*ATTENTION: L'interface doit être conectée pour passer au statut ON

```bash
# Appliquer et redemarer le DHCP
sudo systemctl restart systemd-networkd
sudo systemctl restart isc-dhcp-server
```

> Refaire ces opérations pour chaque vlan supplémentaire

---

# Configuration

A ce stade nous avons configué le DHCP sur les bonnes interfaces, ajouté des vlans, et donné un accès internet **temporaire** su DHCP afin de mettre en place les services. Maintenant on configurera le fichier de configuration.

**Pour ce faire, on configure le fichier avec la commande suivante :**

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

**Ici on declare les vlans, le DNS et la passerelle**

```text
# =============================================
# ISC-DHCP-SERVER - Lab
# =============================================

# Options globales
default-lease-time 86400;      # 24h
max-lease-time 172800;         # 48h
authoritative;
option domain-name "lab.local";
option domain-name-servers 8.8.8.8, 1.1.1.1;

# =============================================
# VLAN 10 - Serveurs
# =============================================
subnet 192.168.10.0 netmask 255.255.255.0 {
  range 192.168.10.100 192.168.10.200;
  option routers 192.168.10.1;
  option broadcast-address 192.168.10.255;
}

# =============================================
# VLAN 20 - Backup
# =============================================
subnet 192.168.20.0 netmask 255.255.255.0 {
  range 192.168.20.100 192.168.20.200;
  option routers 192.168.20.1;
  option broadcast-address 192.168.20.255;
}

# =============================================
# VLAN 30 - IT
# =============================================
subnet 192.168.30.0 netmask 255.255.255.0 {
  range 192.168.30.100 192.168.30.200;
  option routers 192.168.30.1;
  option broadcast-address 192.168.30.255;
}

```
