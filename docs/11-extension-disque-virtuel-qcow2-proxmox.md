# 11 — Sécurisation de Proxmox et extension du disque virtuel QCOW2

## 11.1. Objectif de cette étape

Après l'audit du stockage réalisé dans la section 10, nous avons constaté que le thin pool `local-lvm` de Proxmox VE dispose d'une capacité de 21,42 Gio, insuffisante pour accueillir confortablement les deux futures machines virtuelles `srv01` et `srv02`, dont les disques virtuels auront chacun une capacité de 15 Gio.

L'objectif de cette étape est donc d'augmenter la capacité du disque virtuel de Proxmox, exécuté sous KVM/QEMU sur l'hôte Ubuntu `Kgoumou`.

Le dimensionnement retenu est le suivant :

| Paramètre | Valeur initiale | Valeur cible |
|---|---:|---:|
| Disque virtuel de Proxmox | 64 Gio | 96 Gio |
| Extension prévue | — | +32 Gio |
| Format du disque | QCOW2 | QCOW2 |

Cette extension constitue une première opération. L'agrandissement des partitions et des volumes LVM internes à Proxmox sera réalisé dans la section 12.

## 11.2. Vérification des machines virtuelles sur l'hôte KVM

Avant toute intervention, nous avons vérifié l'état des machines virtuelles gérées par libvirt.

Commande exécutée sur `Kgoumou` :

```bash
virsh list --all
```

**Résultat obtenu :**

```text
 Id   Name               State
-----------------------------------
 1    pve1               running
 -    oracle-db-server   shut off
 -    win10-lab          shut off
```

La machine virtuelle `pve1` était en fonctionnement, tandis que les deux autres machines étaient arrêtées.

## 11.3. Arrêt contrôlé de Proxmox VE

Pour intervenir sur le fichier QCOW2 en toute sécurité, nous avons procédé à un arrêt contrôlé de la machine virtuelle `pve1`.

Commande exécutée :

```bash
virsh shutdown pve1
```

La commande `virsh list` a ensuite été utilisée pour vérifier l'état des machines virtuelles :

```bash
virsh list
```

**Résultat obtenu :**

```text
 Id   Name   State
--------------------
```

Aucune machine virtuelle n'était alors en cours d'exécution. Proxmox VE était donc arrêté.

## 11.4. Création du répertoire de sauvegarde

Avant de modifier le disque virtuel, nous avons créé un répertoire dédié à la sauvegarde de la VM Proxmox.

Commande exécutée :

```bash
sudo mkdir -p ~/lab/kvm/templates/pve1-backup
```

Ce répertoire permet de séparer la copie de sauvegarde du fichier QCOW2 utilisé directement par libvirt.

Chemin de sauvegarde retenu :

```text
/home/kaman-goumou/lab/kvm/templates/pve1-backup/
```

## 11.5. Copie du disque virtuel de Proxmox

La VM étant arrêtée, nous avons créé une copie du fichier QCOW2.

Commande exécutée :

```bash
sudo cp --sparse=always --reflink=auto \
/var/lib/libvirt/images/pve1.qcow2 \
~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

Cette commande copie le fichier tout en préservant son caractère sparse lorsque cela est possible.

Le paramètre `--sparse=always` permet de préserver les zones non allouées sous forme de trous dans le fichier, tandis que `--reflink=auto` tente d'utiliser une copie à partage de blocs si le système de fichiers le permet.

### Vérification des fichiers

Commande exécutée :

```bash
sudo ls -lh \
/var/lib/libvirt/images/pve1.qcow2 \
~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

**Résultat obtenu :**

```text
-rw-r--r-- 1 root         root 2.0G Nov  6 01:36 /home/kaman-goumou/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
-rw-r--r-- 1 libvirt-qemu kvm  2.0G Nov  6 01:32 /var/lib/libvirt/images/pve1.qcow2
```

Les deux fichiers sont présents et affichent une taille occupée d'environ 2 Gio.

## 11.6. Vérification de l'intégrité de la sauvegarde

Pour confirmer que la copie est identique au disque original, nous avons calculé les empreintes SHA-256 des deux fichiers.

Commande exécutée :

```bash
sudo sha256sum \
/var/lib/libvirt/images/pve1.qcow2 \
~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

**Résultat obtenu :**

```text
bf14771192a2bee2a424af0d3d06a3abcbf4ec7d52c5ce1e433998ac3b22d6e2  /var/lib/libvirt/images/pve1.qcow2
bf14771192a2bee2a424af0d3d06a3abcbf4ec7d52c5ce1e433998ac3b22d6e2  /home/kaman-goumou/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

Les deux empreintes SHA-256 sont strictement identiques.

Cette vérification confirme que la copie de sauvegarde est identique au fichier original, octet par octet.

**Remarque :** la sauvegarde est stockée sur le même SSD physique que le disque original. Elle permet de revenir au fichier initial en cas de problème lié à l'opération de redimensionnement, mais ne constitue pas une protection contre une panne physique du SSD.

## 11.7. Vérification des images QCOW2 avant modification

Avant de procéder au redimensionnement, nous avons vérifié les caractéristiques des deux images.

### Disque original

Commande exécutée :

```bash
sudo qemu-img info /var/lib/libvirt/images/pve1.qcow2
```

**Résultat obtenu :**

```text
image: /var/lib/libvirt/images/pve1.qcow2
file format: qcow2
virtual size: 64 GiB (68719476736 bytes)
disk size: 1.98 GiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: /var/lib/libvirt/images/pve1.qcow2
    protocol type: file
    file length: 1.99 GiB (2132148224 bytes)
    disk size: 1.98 GiB
```

### Copie de sauvegarde

Commande exécutée :

```bash
sudo qemu-img info ~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

**Résultat obtenu :**

```text
image: /home/kaman-goumou/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
file format: qcow2
virtual size: 64 GiB (68719476736 bytes)
disk size: 1.98 GiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: /home/kaman-goumou/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
    protocol type: file
    file length: 1.99 GiB (2132148224 bytes)
    disk size: 1.98 GiB
```

Les deux images sont au format QCOW2, disposent d'une capacité virtuelle de 64 Gio et ne sont pas signalées comme corrompues.

Aucun fichier parent n'est indiqué dans les informations de ces images.

## 11.8. Extension de la capacité du disque QCOW2

Après validation de la sauvegarde et vérification de l'image originale, nous avons procédé à l'extension de sa capacité virtuelle.

La commande exécutée sur `Kgoumou` est :

```bash
sudo qemu-img resize /var/lib/libvirt/images/pve1.qcow2 96G
```

**Résultat obtenu :**

```text
Image resized.
```

L'opération a été exécutée avec succès.

Cette commande modifie la capacité virtuelle de l'image QCOW2 sans agrandir automatiquement les partitions ou les volumes LVM présents dans Proxmox.

La copie de sauvegarde n'a pas été modifiée et conserve sa capacité initiale de 64 Gio.

## 11.9. Vérification de la nouvelle capacité du disque

Pour confirmer l'extension, nous avons exécuté :

```bash
sudo qemu-img info /var/lib/libvirt/images/pve1.qcow2
```

**Résultat obtenu :**

```text
image: /var/lib/libvirt/images/pve1.qcow2
file format: qcow2
virtual size: 96 GiB (103079215104 bytes)
disk size: 1.98 GiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: /var/lib/libvirt/images/pve1.qcow2
    protocol type: file
    file length: 1.99 GiB (2132148224 bytes)
    disk size: 1.98 GiB
```

La vérification confirme que la capacité virtuelle du disque est désormais de 96 Gio, contre 64 Gio initialement.

L'espace réellement occupé sur le SSD reste proche de 1,98 Gio, car l'extension de capacité n'a pas entraîné l'écriture de 32 Gio de nouvelles données.

## 11.10. Bilan de l'opération

| Élément | Avant | Après |
|---|---:|---:|
| Capacité virtuelle du disque QCOW2 | 64 Gio | 96 Gio |
| Extension de capacité | — | +32 Gio |
| Espace réellement occupé | 1,98 Gio | 1,98 Gio |
| Format | QCOW2 | QCOW2 |
| Sauvegarde vérifiée par SHA-256 | Oui | Oui |

L'opération de redimensionnement du fichier QCOW2 est terminée avec succès.

À ce stade, seule la capacité du disque virtuel sur l'hôte KVM a été augmentée. Les partitions internes de Proxmox et le stockage `local-lvm` conservent encore leurs dimensions initiales.

## 11.11. Transition vers la section 12

La prochaine étape consistera à redémarrer Proxmox VE et à vérifier que le système détecte le nouveau disque de 96 Gio.

Nous procéderons ensuite à l'extension de la partition `/dev/vda3`, du volume physique LVM et du thin pool `pve-data`.

Ces opérations feront l'objet de la section suivante :

**Section 12 — Détection du nouveau disque et extension du stockage LVM-Thin dans Proxmox VE.**