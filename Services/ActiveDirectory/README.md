# Configuration de l'Active Directory pour le projet CyberEnv

Ce guide documente la mise en place complète d'un contrôleur de domaine (DC) Samba 4 sur Ubuntu Server Minimized pour le domaine `sio.lan`.

## 1. Préparation de l'identité et du réseau

La première étape consiste à définir l'identité de la machine et à configurer une IP statique avec un accès internet temporaire pour installer les paquets nécessaires.

### Configuration du Hostname

```bash
sudo hostnamectl set-hostname sioad
exec bash

```

### Résolution locale (/etc/hosts)

Modifiez le fichier pour que le nom de domaine complet (FQDN) pointe vers l'IP statique.

```bash
sudo nano /etc/hosts

```

**Contenu à insérer :**

```text
127.0.0.1     localhost
192.168.10.4  sioad.sio.lan sioad

```

### Configuration réseau via Netplan

Assurez-vous d'utiliser un DNS externe (comme 8.8.8.8) au début pour permettre le téléchargement des dépôts.

```bash
sudo nano /etc/netplan/00-netconfig.yaml

```

**Structure recommandée :**

```yaml
network:
  version: 2
  ethernets:
    ens18: # À vérifier avec 'ip a'
      addresses:
        - 192.168.10.4/24
      routes:
        - to: default
          via: 192.168.10.254
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

Appliquez les changements : `sudo netplan apply`

## 2. Installation et nettoyage des services

Nous installons Samba et les outils Kerberos, puis nous désactivons les services Ubuntu qui entrent en conflit avec le rôle de contrôleur de domaine.

### Installation des paquets

```bash
sudo apt update && sudo apt install -y samba krb5-config krb5-user winbind libpam-winbind libnss-winbind python3-setproctitle acl

```

### Neutralisation des services conflictuels

Samba AD intègre son propre serveur DNS et ses démons de fichiers. Il faut donc arrêter les services standards.

```bash
sudo systemctl stop smbd nmbd winbind systemd-resolved
sudo systemctl disable smbd nmbd winbind systemd-resolved
sudo systemctl mask smbd nmbd winbind

```

### Configuration DNS statique

```bash
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf
echo "search sio.lan" | sudo tee -a /etc/resolv.conf

```

## 3. Provisionnement du Domaine AD

Cette étape crée physiquement la base de données de l'Active Directory.

```bash
# Suppression de la configuration par défaut
sudo rm -f /etc/samba/smb.conf

# Création du domaine
sudo samba-tool domain provision \
  --use-rfc2307 \
  --realm=SIO.LAN \
  --domain=SIO \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --adminpass='sioPBA29200'

```

## 4. Finalisation et connectivité Internet

Une fois le domaine créé, nous activons le service spécifique `samba-ad-dc` et configurons le transfert DNS (Forwarder) pour conserver l'accès à Google.

### Activation du service

```bash
sudo systemctl unmask samba-ad-dc
sudo systemctl enable samba-ad-dc
sudo systemctl start samba-ad-dc

```

### Configuration du DNS Forwarder

```bash
sudo nano /etc/samba/smb.conf

```

Ajoutez cette ligne dans la section `[global]` pour que le serveur puisse résoudre les noms externes :

```ini
dns forwarder = 8.8.8.8

```

Redémarrez le service pour appliquer : `sudo systemctl restart samba-ad-dc`

### Liaison Kerberos

Copiez le fichier de configuration généré par Samba vers le répertoire système.

```bash
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

```

## 5. Vérification du fonctionnement

Testez si l'administrateur peut obtenir un ticket Kerberos valide.

```bash
echo "--- TEST KERBEROS ---"
echo "MotDePasse" | kinit administrator@SIO.LAN
klist

```

### Mise à jour finale du réseau

Maintenant que le service est opérationnel, modifiez votre fichier Netplan pour que le serveur n'utilise que lui-même comme DNS (`addresses: [127.0.0.1]`) et appliquez de nouveau la configuration.

```yaml
network:
  version: 2
  ethernets:
    ens18: # À vérifier avec 'ip a'
      addresses:
        - 192.168.10.4/24
      routes:
        - to: default
          via: 192.168.10.254
      nameservers:
        addresses: [127.0.0.1] # <-- ici !
```
