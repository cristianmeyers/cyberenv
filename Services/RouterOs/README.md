# Configuration du Routeur

Pour ce lab, le routeur utilisé sera un **Mikrotik**. Il aura pour rôle de gérer les **connexions inter-VLAN** ainsi que la **sortie vers Internet**.

Pour se connecter au routeur, deux méthodes sont possibles :

- Avec un **câble console** via l’outil `Winbox`.
- Avec un **câble RJ45** directement connecté à un port LAN.

> Dans notre cas, la deuxième option sera privilégiée car elle est plus simple et ne nécessite pas l’installation de logiciels supplémentaires.

## Connexion au Routeur

Par défaut, l’adresse IP du routeur est `192.168.88.1`.  
Nous devons donc attribuer une adresse IP **statique** à notre ordinateur : `192.168.88.50`.

Cela permettra d’accéder au routeur depuis le réseau local, notamment via son interface web (`http://192.168.88.1`), ou par **SSH** avec l’utilisateur par défaut **admin** (sans mot de passe initialement).

Pour établir une connexion SSH :

```bash
ssh admin@192.168.88.1
```

## Configuration WAN

Lister les interfaces disponibles :

```bash
/interface ethernet print
```

La sortie devra resembler à ceci :

```text
Flags: X - disabled, R - running, S - slave
 #    NAME                TYPE       ACTUAL-MTU L2MTU  MAX-L2MTU
 0  R ether1              ether            1500  1598       4074
 1  R ether2              ether            1500  1598       4074
 2  R ether3              ether            1500  1598       4074
 3  R ether4              ether            1500  1598       4074
 4  R ether5              ether            1500  1598       4074
```

Dans cet exemple :

- `ether1` servira de **port WAN** (vers Internet)
- `ether2–ether5` seront utilisés pour le **LAN** et les **VLANs**

---

## Configuration de l’adresse IP WAN

On va d'abbord supprimer la posible addresse IP par default de l'interface.

```bash
/ip address print
```

**sortie similaire :**

```text
Flags: D - DYNAMIC
 #   ADDRESS            NETWORK       INTERFACE
 0   192.168.56.10/24   192.168.56.0  ether1
 1   192.168.1.1/24     192.168.1.0   ether2
 2 D 10.0.4.15/24       10.0.4.0      ether3
```

`ether1` est l'interface dans l'aquelle on veut avoir un `client DHCP`
on supprime donc l'addresse **IP** si jamais il y en a une.

```bash
/ip address remove [find interface=ether1]
```

**Renommer l'interface pour plus de clarté:**

```bash
/interface ethernet set ether1 name=WAN
```

Attribuer une adresse IP obtenue automatiquement via DHCP (fournie par le modem, le FAI ou en Nat si configuration en vm) :

```bash
/ip dhcp-client add interface=WAN disabled=no
```

Vérifier que l’adresse IP a bien été reçue :

```bash
/ip dhcp-client print
```

---

## Configuration de la passerelle et du DNS

Les paramètres DNS sont souvent attribués automatiquement par le DHCP, mais on peut les définir manuellement :

```bash
/ip dns set servers=8.8.8.8,8.8.4.4 allow-remote-requests=yes
```

Cela permet aussi aux clients internes d’utiliser le routeur comme **DNS relay**.

---

## Configuration LAN

Attribuer une adresse IP locale pour le réseau interne (exemple VLAN 10 - Serveurs) :

```bash
/ip address add address=10.10.10.1/24 interface=ether2 comment="LAN - Serveurs"
```

On répète cette opération pour les autres VLANs si nécessaire :

```bash
/ip address add address=10.10.20.1/24 interface=ether3 comment="LAN - Backup"
/ip address add address=10.10.30.1/24 interface=ether4 comment="LAN - IT"
```

---

## Configuration du NAT (Sortie Internet)

Afin que les machines internes puissent accéder à Internet, il faut configurer la **traduction d’adresses** (NAT) :

```bash
/ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade
```

Cette règle permet à tout le trafic sortant du LAN vers le WAN d’utiliser l’adresse IP publique du routeur.

---

## Vérification de la connectivité Internet

Tester la connectivité depuis le routeur :

```bash
/ping 8.8.8.8
```

Si la réponse est positive, la sortie Internet est fonctionnelle.

---

## Sauvegarde de la configuration

Une fois la configuration terminée :

```bash
/system backup save name=routeur-lab.backup
/export file=routeur-lab-config
```

Ces fichiers peuvent ensuite être téléchargés pour restauration ou documentation.
