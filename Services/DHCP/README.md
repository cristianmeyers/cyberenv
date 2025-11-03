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

- **Nom** : `enp0s3`
- **MAC** : `08:00:27:c3:fa:15`
- **Etat** : `Up`
- **IP** : `192.168.1.2/24` (Par default il n'y en a pas)

Maintenant faut conecter le seveur a internet via cette interface, je prend enp0s8 comme exemple. pour cela, deux moyen, activer le dhcp, ou utiliser une addresse physique. Dans notre cas, l'option 1 es plus adapté.

```bash
sudo nano /etc/netplan/00-installer-config.yaml

```

et remplir le fichier avec

```yaml
network:
  renderer: networkd
  ethernets:
    enp0s3: # interface en question
      dhcp4: true
```

## Services

## Scripts et aliass l
