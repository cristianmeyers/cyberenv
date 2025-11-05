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

## Configuration VLAN

Les `VLANs` passeront par le même câble et donc utiliseront le mode trunk, facilitant ainsi la gestion. Pour ce faire il faut declarer un bride contenant les differents `VLANs`.

```bash
/interface bridge add name=bridge-vlans
```

**On supprime l'ip de l'interface voulue et on ajoute ce bridge à l'interface**

```bash
/ip address remove [find interface=ether2]
/interface bridge port add bridge=bridge-vlans interface=ether2
```

**Maintenant on peut creer les `VLANs` spécifiques**

```bash
/interface vlan add name=VLAN10 vlan-id=10  interface=bridge-vlans
/interface vlan add name=VLAN20 vlan-id=20  interface=bridge-vlans
/interface vlan add name=VLAN30 vlan-id=30  interface=bridge-vlans
```

**On ajoute une `IP` à chaque vlan et un commentaire pour la getion:**

```bash
/ip address add address=192.168.10.1/24 interface=VLAN10 comment="Serveurs"
/ip address add address=192.168.20.1/24 interface=VLAN20 comment="Backup"
/ip address add address=192.168.30.1/24 interface=VLAN30 comment="IT"
```

> Ces addreces seront la passerelle de chaque VLAN déclaré dans le **DHCP**.

**Maintenant op peut activer le `Tagging 802.1Q` sur le câble Trunk**

```bash
/interface bridge vlan add bridge=bridge-vlans vlan-ids=10 tagged=ether2
/interface bridge vlan add bridge=bridge-vlans vlan-ids=20 tagged=ether2
/interface bridge vlan add bridge=bridge-vlans vlan-ids=30 tagged=ether2
```

> On répète cette opération pour les d'autres **VLANs** si nécessaire.

**On vérifie la configuration et la sortie attendue**

```bash
/interface bridge print
/interface bridge port print
```

Sortie

```text
# NAME          ADMIN-MAC         AGE
0 bridge-vlans  XX:XX:XX:XX:XX:XX  0

# INTERFACE  BRIDGE
0 ether2     bridge-vlans
```

Et les adresses **IP**

```bash
/interface vlan print
/ip address print
```

Sortie

```text
Columns: NAME, MTU, ARP, VLAN-ID, INTERFACE
#   NAME     MTU  ARP      VLAN-ID  INTERFACE
0 R VLAN10  1500  enabled       10  bridge-vlans
1 R VLAN20  1500  enabled       20  bridge-vlans
2 R VLAN30  1500  enabled       30  bridge-vlans

# ADDRESS             NETWORK          INTERFACE
0 10.0.2.15/24        10.0.2.0         WAN
1 192.168.10.1/24     192.168.10.0     VLAN10
2 192.168.20.1/24     192.168.20.0     VLAN20
3 192.168.30.1/24     192.168.30.0     VLAN30
```

---

## Configuration du NAT (Sortie Internet) à revoir

Afin que les machines internes puissent accéder à Internet, il faut configurer la **traduction d’adresses** (NAT) :

```bash
/ip firewall nat add chain=srcnat out-interface=WAN action=masquerade
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
