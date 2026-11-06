# 10 — Audit du stockage KVM et préparation du dimensionnement de Proxmox VE

## 10.1. Objectif de cette étape

L'objectif de cette étape est d'analyser le stockage de la machine hôte `Kgoumou`, sur laquelle Proxmox VE 9.2.25 est exécuté sous forme de machine virtuelle KVM/QEMU.

Cette analyse est nécessaire avant le déploiement de deux machines virtuelles Ubuntu Server 24.04 LTS, qui seront provisionnées à l'aide de Terraform depuis la machine de travail.

Les deux machines prévues sont :

| Paramètre | srv01 | srv02 |
|---|---:|---:|
| Système d'exploitation | Ubuntu Server 24.04 LTS | Ubuntu Server 24.04 LTS |
| Processeur | 1 vCPU | 1 vCPU |
| Mémoire vive | 1 Gio | 1 Gio |
| Disque virtuel | 15 Gio | 15 Gio |

**Besoin total prévisionnel :**
- 2 vCPU ;
- 2 Gio de RAM ;
- 30 Gio de capacité disque virtuelle.

L'audit de la section précédente a montré que le stockage `local-lvm` de Proxmox dispose seulement de 21,42 Gio. Il est donc nécessaire d'étudier une augmentation de capacité avant de créer les deux machines.

L'objectif est de disposer d'un stockage suffisamment dimensionné, sans compromettre le fonctionnement de Proxmox VE ni celui de la machine hôte.

## 10.2. Vérification de l'espace disponible sur l'hôte Kgoumou

Depuis le terminal Ubuntu de la machine hôte `Kgoumou`, la commande suivante permet de contrôler l'espace disponible sur les systèmes de fichiers :

```bash
df -hT
```

**Résultat obtenu :**

```text
Filesystem     Type      Size  Used Avail Use% Mounted on
tmpfs          tmpfs     1.2G  2.0M  1.2G   1% /run
efivarfs       efivarfs  192K  119K   69K  64% /sys/firmware/efi/efivars
/dev/nvme0n1p2 ext4      468G  191G  254G  43% /
tmpfs          tmpfs     5.7G     0  5.7G   0% /dev/shm
tmpfs          tmpfs     5.0M  8.0K  5.0M   1% /run/lock
tmpfs          tmpfs     5.7G     0  5.7G   0% /run/qemu
/dev/nvme0n1p1 vfat      1.1G  6.2M  1.1G   1% /boot/efi
tmpfs          tmpfs     1.2G   92K  1.2G   1% /run/user/1000
```

**Interprétation :**

Le système de fichiers racine de l'hôte, situé sur `/dev/nvme0n1p2`, dispose de 254 Gio disponibles sur une capacité totale de 468 Gio.

Cet espace constitue la réserve physique disponible sur le SSD pour les fichiers des machines virtuelles hébergées par KVM, notamment le disque virtuel de Proxmox.

Il faut toutefois distinguer l'espace disponible sur le SSD de l'hôte de la capacité de stockage présentée à Proxmox.

## 10.3. Identification des machines virtuelles gérées par KVM

La commande suivante permet de lister les machines virtuelles enregistrées dans libvirt :

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

La machine `pve1` est actuellement en fonctionnement. Les deux autres machines virtuelles sont arrêtées.

Proxmox VE est donc lui-même exécuté comme une machine virtuelle KVM sur `Kgoumou`.

## 10.4. Identification du disque virtuel de Proxmox

Pour identifier le fichier disque associé à la machine virtuelle `pve1`, la commande suivante a été exécutée :

```bash
virsh domblklist pve1 --details
```

**Résultat obtenu :**

```text
 Type   Device   Target   Source
--------------------------------------------------------------
 file   disk     vda      /var/lib/libvirt/images/pve1.qcow2
```

Cette sortie confirme que le disque présenté à Proxmox sous le nom `/dev/vda` correspond au fichier suivant sur l'hôte :

```text
/var/lib/libvirt/images/pve1.qcow2
```

Le fichier QCOW2 constitue donc le support de stockage virtuel sur lequel repose le disque système de Proxmox.

## 10.5. Analyse de l'image QCOW2

Une première tentative d'analyse avec la commande `qemu-img info` a retourné une erreur de verrouillage :

```text
qemu-img: Could not open '/var/lib/libvirt/images/pve1.qcow2': Failed to get shared "write" lock
Is another process using the image [/var/lib/libvirt/images/pve1.qcow2]?
```

Cette situation est liée au fait que la machine virtuelle `pve1` est en fonctionnement et que QEMU utilise son image disque.

Pour effectuer une consultation en lecture seule sans demander le verrou exclusif habituel, l'option `--force-share` a été utilisée :

```bash
qemu-img info --force-share /var/lib/libvirt/images/pve1.qcow2
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
    file length: 1.98 GiB (2128740352 bytes)
    disk size: 1.98 GiB
```

**Interprétation :**

- Format du disque : QCOW2.
- Capacité virtuelle : 64 Gio.
- Espace réellement occupé : 1,98 Gio.
- État de corruption signalé : `false`.

Le format QCOW2 permet une allocation dynamique : le fichier peut grandir progressivement en fonction des données écrites par la machine virtuelle.

La capacité virtuelle de 64 Gio ne signifie donc pas que 64 Gio sont immédiatement consommés sur le SSD de l'hôte.

## 10.6. Vérification de l'espace réellement occupé

Pour confirmer l'espace réellement consommé par le fichier, la commande suivante a été exécutée :

```bash
du -h /var/lib/libvirt/images/pve1.qcow2
```

**Résultat obtenu :**

```text
2.0G    /var/lib/libvirt/images/pve1.qcow2
```

Cette mesure est cohérente avec les 1,98 Gio annoncés par `qemu-img info`.

## 10.7. Vérification de la chaîne de dépendances QCOW2

Il est important de vérifier si l'image disque dépend d'un autre fichier, notamment d'une image parente.

Commande exécutée :

```bash
qemu-img info --force-share --backing-chain /var/lib/libvirt/images/pve1.qcow2
```

Le résultat confirme que l'image examinée est autonome : aucun fichier parent (*backing file*) n'est affiché.

Cette vérification est importante avant toute opération de redimensionnement ou de maintenance du disque virtuel.

## 10.8. Vérification des snapshots de la machine virtuelle

La commande suivante a été exécutée :

```bash
virsh snapshot-list pve1 --tree
```

Aucun résultat n'a été retourné.

Cela signifie qu'aucun snapshot n'est répertorié par libvirt pour la machine virtuelle `pve1`.

Cette vérification ne remplace toutefois pas une sauvegarde complète de la machine virtuelle.

## 10.9. Vérification des ressources de la machine virtuelle Proxmox

La configuration générale de la VM a été consultée avec :

```bash
virsh dominfo pve1
```

**Résultat obtenu :**

```text
Id:             1
Name:           pve1
UUID:           c68403c4-1359-4219-84b5-048f89b6810f
OS Type:        hvm
State:          running
CPU(s):         2
CPU time:       162.0s
Max memory:     6291456 KiB
Used memory:    6291456 KiB
Persistent:     yes
Autostart:      disable
Managed save:   no
Security model: apparmor
Security DOI:   0
Security label: libvirt-c68403c4-1359-4219-84b5-048f89b6810f (enforcing)
```

**Interprétation :**

La machine virtuelle Proxmox dispose de :
- 2 processeurs virtuels ;
- 6 Gio de mémoire vive ;
- un démarrage automatique désactivé.

Proxmox utilise donc actuellement 2 vCPU et 6 Gio de RAM sur l'hôte KVM.

Les deux futures VM disposeront chacune de 1 vCPU et 1 Gio de RAM. Ces ressources devront être prises en compte dans le dimensionnement global de l'environnement.

## 10.10. Analyse de la configuration XML de la VM pve1

Pour examiner la configuration détaillée de la machine virtuelle, la commande suivante a été exécutée :

```bash
virsh dumpxml pve1
```

Les éléments importants relevés dans le résultat sont :

```xml
<memory unit='KiB'>6291456</memory>
<currentMemory unit='KiB'>6291456</currentMemory>
<vcpu placement='static'>2</vcpu>
```

Configuration du disque :

```xml
<disk type='file' device='disk'>
  <driver name='qemu' type='qcow2'/>
  <source file='/var/lib/libvirt/images/pve1.qcow2' index='1'/>
  <backingStore/>
  <target dev='vda' bus='virtio'/>
</disk>
```

Cette configuration confirme que :
- le disque est au format QCOW2 ;
- son fichier est stocké dans `/var/lib/libvirt/images/` ;
- le périphérique présenté à Proxmox est `/dev/vda` ;
- le bus utilisé est VirtIO.

Le disque virtuel est donc bien identifié de bout en bout, depuis le stockage physique de l'hôte jusqu'au périphérique visible dans Proxmox.

## 10.11. Vérification de la structure du disque dans Proxmox

Les commandes suivantes ont été exécutées depuis le Shell de Proxmox VE.

### Identification des partitions

```bash
fdisk -l /dev/vda
```

**Résultat obtenu :**

```text
Disk /dev/vda: 64 GiB, 68719476736 bytes, 134217728 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 13DC6D10-32BA-4A24-B90B-CB8885C61FE6

Device       Start       End   Sectors  Size Type
/dev/vda1       34      2047      2014 1007K BIOS boot
/dev/vda2     2048   1050623   1048576  512M EFI System
/dev/vda3  1050624 134217694 133167071 63.5G Linux LVM
```

Le disque utilise une table de partitions GPT et contient trois partitions :
- `/dev/vda1` : partition BIOS boot ;
- `/dev/vda2` : partition EFI ;
- `/dev/vda3` : partition Linux LVM.

La partition `/dev/vda3` occupe presque toute la capacité disponible du disque.

### Tentative d'affichage de l'espace libre avec parted

Commande exécutée :

```bash
parted /dev/vda unit GiB print free
```

Résultat :

```text
-bash: parted: command not found
```

L'utilitaire `parted` n'est pas installé dans l'environnement Proxmox. Cette commande n'a donc pas permis d'afficher les informations demandées.

### Vérification de l'espace non partitionné

Pour obtenir cette information avec un autre outil :

```bash
sfdisk --list-free /dev/vda
```

**Résultat obtenu :**

```text
Unpartitioned space /dev/vda: 0 B, 0 bytes, 0 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
```

Aucun espace non partitionné n'est actuellement disponible sur `/dev/vda`.

## 10.12. Vérification de l'espace disponible dans LVM

La commande suivante a permis de contrôler la capacité du volume physique :

```bash
pvs --units g
```

**Résultat obtenu :**

```text
PV         VG  Fmt  Attr PSize  PFree
/dev/vda3  pve lvm2 a--  63.50g 7.88g
```

**Interprétation :**

Le volume physique `/dev/vda3` appartient au groupe de volumes `pve`.

Sa capacité est de 63,50 Gio, dont 7,88 Gio ne sont pas encore alloués à un volume logique.

Il faut distinguer trois notions :

| Élément | Capacité |
|---|---:|
| Espace non partitionné sur `/dev/vda` | 0 Gio |
| Espace libre dans le groupe LVM `pve` | 7,88 Gio |
| Thin pool `pve-data` | 21,42 Gio |

Les 7,88 Gio libres dans le groupe LVM ne constituent pas de l'espace non partitionné : ils sont déjà situés à l'intérieur du volume physique `/dev/vda3`.

## 10.13. Bilan de l'audit et décision de dimensionnement

L'ensemble des vérifications permet d'établir la situation suivante :

| Élément | État actuel |
|---|---:|
| Stockage disponible sur l'hôte Kgoumou | 254 Gio |
| Disque virtuel de Proxmox | 64 Gio |
| Espace réellement occupé par le QCOW2 | 1,98 Gio |
| Partition Linux LVM `/dev/vda3` | 63,5 Gio |
| Espace libre dans le VG `pve` | 7,88 Gio |
| Thin pool `pve-data` | 21,42 Gio |
| Besoin disque de srv01 et srv02 | 30 Gio |

Le thin pool actuel de 21,42 Gio est inférieur aux 30 Gio de capacité logique prévus pour les deux futures machines.

Le thin provisioning permet de créer des disques virtuels dont la capacité logique totale dépasse la capacité physique actuellement consommée. Cependant, cela ne garantit pas que les deux machines pourront utiliser simultanément leurs 30 Gio complets.

Pour éviter une saturation du thin pool, il est donc préférable d'augmenter la capacité disponible avant le déploiement.

### Dimensionnement envisagé

Une extension du disque virtuel de Proxmox de 64 à 96 Gio est envisagée.

Cette extension représenterait 32 Gio de capacité virtuelle supplémentaire. Elle devra ensuite être répercutée dans Proxmox, en respectant l'ordre des opérations :

1. Arrêt contrôlé de la machine virtuelle Proxmox.
2. Vérification préalable de la sauvegarde de la VM.
3. Extension du fichier QCOW2 sur l'hôte KVM.
4. Redémarrage de Proxmox et détection de la nouvelle capacité.
5. Extension de la partition `/dev/vda3`.
6. Redimensionnement du volume physique LVM.
7. Extension du thin pool `pve-data`.
8. Vérification finale des capacités de stockage.

Le dimensionnement définitif du thin pool devra conserver une réserve pour les métadonnées et les autres volumes du système Proxmox.

**Important :** à la fin de cette section, aucune extension du disque QCOW2, de la partition ou du thin pool n'a encore été effectuée. Les opérations de modification restent à réaliser après validation de la sauvegarde et du dimensionnement final.

## 10.14. Objectif final de cette préparation

À l'issue de cette préparation, l'environnement devra être suffisamment dimensionné pour permettre le déploiement automatisé des deux machines virtuelles suivantes avec Terraform :

- `srv01` : Ubuntu Server 24.04 LTS, 1 vCPU, 1 Gio de RAM et 15 Gio de disque.
- `srv02` : Ubuntu Server 24.04 LTS, 1 vCPU, 1 Gio de RAM et 15 Gio de disque.

Le stockage des disques de ces deux machines sera placé sur `local-lvm`, tandis que le stockage `local` restera destiné aux ISO, aux modèles de conteneurs et aux sauvegardes.

Cette séparation permettra de conserver une organisation claire du stockage Proxmox et de préparer un environnement de laboratoire reproductible et administrable avec Terraform.