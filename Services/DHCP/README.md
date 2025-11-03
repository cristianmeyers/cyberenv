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

Maintenant faut conecter le seveur a internet via cette interface, je prend enp0s8 comme exemple. pour cela, deux moyen, activer le dhcp, ou utiliser une addresse physique. Dans notre cas, l'option 1 es plus adapté.

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

On test la l'application des configs pour eviter une deconnexion du serveur si on est connecté par SSH, et si pas d'erreur, on **applique**. puis on active l'interface.

```bash
sudo netplan try  # pour tester si pas d'erreur du fichier netplan
sudo netplan apply  # appliquer
sudo ip link set enp0s8 up  # attention au nom de l'interface !!
```

Plus qu'a vérifier avec `ip a` pour confirmer l'existance d'une addresses IP, et `ping 8.8.8.8` pour tester la connexion internet

**On configure le dhcp pour ecouter sur son interface**

```bash
nano /etc/default/isc-dhcp-server
```

Sur la ligne interface on lui fait écouter l'interface `INTERFACESv4="enp0s8"`

## Services

On aura besoin de telecharger le service `isc-dhcp-server` pour créer le seveur DHCP, de le lancer, et l'activer !

```bash
sudo apt update -y
sudo apt install isc-dhcp-server
sudo systemctl start isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl status isc-dhcp-server
```

> **Note** : à chaque changement sur le fichier dhcp.conf faut redemarer le service et verifier son état ! un script le fera.

## Scripts et aliass
