# 09 — Audit du stockage et vérification des ressources de Proxmox VE avant le déploiement des machines virtuelles

## 1. Objectifs

Avant de procéder au déploiement des machines virtuelles avec Terraform, il est nécessaire d'effectuer un audit des ressources disponibles sur le serveur Proxmox VE.

Cette étape permet de connaître précisément les capacités de stockage, l'espace disponible, la configuration LVM-Thin, les ressources CPU et la mémoire RAM attribuées à Proxmox.

L'objectif est de s'assurer que l'infrastructure dispose de ressources suffisantes pour accueillir les futures machines virtuelles, tout en conservant une marge de fonctionnement pour l'hyperviseur.

Les vérifications portent sur les éléments suivants :

- Inventaire des stockages configurés dans Proxmox.
- Vérification de la capacité des systèmes de fichiers.
- Identification des disques et volumes logiques.
- Analyse du groupe de volumes LVM.
- Vérification du pool LVM-Thin.
- Contrôle du mécanisme de surveillance et d'extension automatique.
- Vérification des volumes virtuels existants.
- Analyse des ressources CPU et RAM.
- Identification de l'environnement de virtualisation sous-jacent.

## 2. Environnement concerné

Les vérifications sont réalisées directement sur le serveur Proxmox VE.

| Élément | Valeur |
|---|---|
| Nom du serveur | pve1 |
| FQDN | pve1.crg-bank.lan |
| Adresse IP | 192.168.122.32 |
| Hyperviseur | Proxmox VE |
| Version | 9.2.25 |
| Hyperviseur sous-jacent | KVM / QEMU |
| Disque virtuel principal | /dev/vda |
| Capacité du disque virtuel | 64 Gio |

**Architecture de virtualisation :**

Proxmox VE est lui-même exécuté dans une machine virtuelle hébergée sur KVM. Les ressources visibles depuis Proxmox correspondent donc aux ressources virtuelles qui lui ont été attribuées par l'hôte KVM.

## 3. Inventaire des stockages Proxmox

### 3.1 Vérification des stockages disponibles

La première vérification consiste à identifier les stockages déclarés dans Proxmox et à examiner leur état.

**Commande exécutée :**

```bash
pvesm status
```

**Résultat obtenu :**

```text
Name             Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
local             dir     active        27102164         5592368        20107736   20.63%
local-lvm     lvmthin     active        22462464               0        22462464    0.00%
```

### Explication technique

La commande `pvesm status` permet de consulter l'état des stockages configurés dans Proxmox.

Les colonnes principales sont :

- `Name` : nom du stockage.
- `Type` : technologie utilisée par le stockage.
- `Status` : état de disponibilité.
- `Total` : capacité totale.
- `Used` : espace utilisé.
- `Available` : espace disponible.
- `%` : pourcentage d'utilisation.

Deux stockages sont identifiés :

**Stockage local (`local`)**

- Type : `dir`.
- Capacité : environ 25,85 Gio.
- Espace utilisé : environ 5,33 Gio.
- Espace disponible : environ 19,18 Gio.
- Taux d'utilisation : 20,63 %.

Il s'agit d'un stockage de type répertoire, utilisé notamment pour les images ISO, les templates de conteneurs et les sauvegardes.

**Stockage local-LVM (`local-lvm`)**

- Type : `lvmthin`.
- Capacité : environ 21,42 Gio.
- Espace utilisé : 0 Gio.
- Espace disponible : environ 21,42 Gio.
- Taux d'utilisation : 0 %.

Il s'agit d'un stockage basé sur LVM-Thin, principalement destiné aux disques des machines virtuelles et aux volumes des conteneurs.

Les deux stockages sont indiqués comme actifs.

## 4. Vérification des systèmes de fichiers

### 4.1 Identification des systèmes de fichiers montés

Après l'inventaire des stockages Proxmox, nous vérifions les systèmes de fichiers et leur capacité.

**Commande exécutée :**

```bash
df -hT
```

**Résultat obtenu :**

```text
Filesystem           Type      Size  Used Avail Use% Mounted on
udev                 devtmpfs  2.3G     0  2.3G   0% /dev
tmpfs                tmpfs     591M  904K  590M   1% /run
/dev/mapper/pve-root ext4       26G  5.4G   20G  22% /
tmpfs                tmpfs     2.9G   28M  2.9G   1% /dev/shm
efivarfs             efivarfs  256K   74K  177K  30% /sys/firmware/efi/efivars
tmpfs                tmpfs     5.0M     0  5.0M   0% /run/lock
tmpfs                tmpfs     1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
tmpfs                tmpfs     2.9G     0  2.9G   0% /tmp
/dev/vda2            vfat      511M  9.1M  502M   2% /boot/efi
/dev/fuse            fuse      128M   28K  128M   1% /etc/pve
tmpfs                tmpfs     1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs                tmpfs     1.0M     0  1.0M   0% /run/credentials/serial-getty@ttyS0.service
tmpfs                tmpfs     591M  4.0K  591M   1% /run/user/0
```

### Explication technique

La commande `df` permet de consulter l'utilisation de l'espace disque des systèmes de fichiers montés.

Les options utilisées sont :

- `-h` : affiche les tailles dans un format lisible (Ko, Mo, Go).
- `-T` : affiche le type du système de fichiers.

Le résultat montre notamment :

| Système de fichiers | Type | Taille | Utilisé | Disponible |
|---|---|---:|---:|---:|
| /dev/mapper/pve-root | ext4 | 26 Gio | 5,4 Gio | 20 Gio |
| /dev/vda2 | vfat | 511 Mio | 9,1 Mio | 502 Mio |
| /dev/fuse | fuse | 128 Mio | 28 Kio | 128 Mio |

Le volume `/dev/mapper/pve-root` correspond au système de fichiers racine de Proxmox.

Le stockage `local`, qui utilise le répertoire `/var/lib/vz`, repose sur ce système de fichiers.

La commande montre également que la partition EFI est montée sur `/boot/efi`.

**Remarque :** les systèmes `tmpfs` et `udev` correspondent à des espaces mémoire temporaires ou à des systèmes virtuels. Ils ne représentent pas des espaces supplémentaires sur le disque physique.

## 5. Identification du disque et des volumes logiques

### 5.1 Vérification de la structure du disque

Pour comprendre comment le disque virtuel est partitionné et comment les volumes logiques sont organisés, nous utilisons `lsblk`.

**Commande exécutée :**

```bash
lsblk
```

**Résultat obtenu :**

```text
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda                253:0    0   64G  0 disk
├─vda1             253:1    0 1007K  0 part
├─vda2             253:2    0  512M  0 part /boot/efi
└─vda3             253:3    0 63.5G  0 part
  ├─pve-swap       252:0    0  5.8G  0 lvm  [SWAP]
  ├─pve-root       252:1    0 26.4G  0 lvm  /
  ├─pve-data_tmeta 252:2    0    1G  0 lvm
  │ └─pve-data     252:4    0 21.4G  0 lvm
  └─pve-data_tdata 252:3    0 21.4G  0 lvm
    └─pve-data     252:4    0 21.4G  0 lvm
```

### Explication technique

Le serveur Proxmox dispose d'un disque virtuel de 64 Gio identifié par `/dev/vda`.

Ce disque est organisé en trois partitions :

- `/dev/vda1` : partition technique de 1007 Kio.
- `/dev/vda2` : partition EFI de 512 Mio.
- `/dev/vda3` : partition de 63,5 Gio utilisée par LVM.

La partition `/dev/vda3` contient le groupe de volumes `pve`.

Dans ce groupe, plusieurs volumes logiques sont identifiés :

| Volume logique | Taille approximative | Fonction |
|---|---:|---|
| pve-swap | 5,8 Gio | Mémoire d'échange |
| pve-root | 26,4 Gio | Système Proxmox |
| pve-data | 21,4 Gio | Pool LVM-Thin destiné aux VM et conteneurs |

Le pool `pve-data` est constitué de deux composants importants :

- `pve-data_tdata` : espace destiné aux données des volumes virtuels.
- `pve-data_tmeta` : espace destiné aux métadonnées qui gèrent les allocations dans le Thin Pool.

La technologie LVM-Thin permet d'allouer des disques virtuels de manière dynamique. L'espace physique n'est consommé qu'au fur et à mesure de l'écriture effective des données.

## 6. Analyse de la configuration des stockages Proxmox

### 6.1 Lecture du fichier storage.cfg

Afin de connaître les paramètres et les contenus autorisés sur chaque stockage, nous examinons le fichier de configuration de Proxmox.

**Commande exécutée :**

```bash
cat /etc/pve/storage.cfg
```

**Résultat obtenu :**

```text
dir: local
    path /var/lib/vz
    content iso,vztmpl,backup,import

lvmthin: local-lvm
    thinpool data
    vgname pve
    content rootdir,images
```

### Explication technique

Ce fichier définit les stockages connus de Proxmox et les types de contenus autorisés.

**Stockage `local`**

```text
dir: local
    path /var/lib/vz
    content iso,vztmpl,backup,import
```

- `dir` : stockage de type répertoire.
- `path` : chemin du répertoire de stockage.
- `iso` : images ISO.
- `vztmpl` : templates de conteneurs LXC.
- `backup` : sauvegardes.
- `import` : contenus destinés à l'importation.

**Stockage `local-lvm`**

```text
lvmthin: local-lvm
    thinpool data
    vgname pve
    content rootdir,images
```

- `lvmthin` : stockage basé sur LVM-Thin.
- `thinpool data` : nom du pool Thin utilisé.
- `vgname pve` : groupe de volumes LVM.
- `rootdir` : volumes des conteneurs.
- `images` : disques des machines virtuelles.

Pour notre projet Terraform, le stockage `local-lvm` sera utilisé principalement pour accueillir les disques des futures machines virtuelles.

## 7. Vérification détaillée de LVM-Thin

### 7.1 Analyse des volumes logiques

Nous examinons maintenant les volumes logiques et les informations relatives au pool Thin.

**Commande exécutée :**

```bash
lvs -a -o lv_name,vg_name,lv_size,lv_attr,data_percent,metadata_percent
```

**Résultat obtenu :**

```text
  LV              VG  LSize   Attr       Data%  Meta%
  data            pve  21.42g twi-a-tz-- 0.00   1.58
  [data_tdata]    pve  21.42g Twi-ao----
  [data_tmeta]    pve   1.00g ewi-ao----
  [lvol0_pmspare] pve   1.00g ewi-------
  root            pve <26.43g -wi-ao----
  swap            pve  <5.77g -wi-ao----
```

### Explication technique

La commande `lvs` affiche les volumes logiques et leurs caractéristiques.

Les paramètres utilisés sont :

- `-a` : affiche également les volumes logiques internes.
- `-o` : sélectionne les colonnes à afficher.
- `lv_name` : nom du volume logique.
- `vg_name` : groupe de volumes.
- `lv_size` : taille du volume.
- `lv_attr` : attributs du volume.
- `data_percent` : pourcentage d'utilisation des données du Thin Pool.
- `metadata_percent` : pourcentage d'utilisation des métadonnées.

Les valeurs importantes sont :

| Indicateur | Résultat |
|---|---:|
| Taille du pool `data` | 21,42 Gio |
| Data% | 0,00 % |
| Meta% | 1,58 % |
| Taille de `data_tmeta` | 1 Gio |
| Taille de `data_tdata` | 21,42 Gio |

Le pool ne présente aucune utilisation de données virtuelles au moment de la vérification.

Les métadonnées sont utilisées à hauteur de 1,58 %.

Les volumes entre crochets, tels que `[data_tmeta]` et `[data_tdata]`, correspondent aux composants internes du Thin Pool.

Le volume `[lvol0_pmspare]` est un volume de réserve destiné à certaines opérations de réparation des métadonnées LVM.

## 8. Vérification de l'espace libre dans le groupe de volumes

### 8.1 Vérification du groupe de volumes

**Commande exécutée :**

```bash
vgs
```

**Résultat obtenu :**

```text
  VG  #PV #LV #SN Attr   VSize   VFree
  pve   1   3   0 wz--n- <63.50g <7.88g
```

### Explication technique

La commande `vgs` affiche les informations relatives aux groupes de volumes LVM.

Les colonnes principales sont :

- `VG` : nom du groupe de volumes.
- `#PV` : nombre de volumes physiques.
- `#LV` : nombre de volumes logiques.
- `VSize` : taille totale du groupe de volumes.
- `VFree` : espace libre non encore alloué.

Le groupe de volumes `pve` possède :

- Une capacité totale d'environ 63,50 Gio.
- Un seul volume physique.
- Un espace non alloué d'environ 7,88 Gio.

Ces 7,88 Gio représentent une réserve disponible dans le groupe LVM. Ils ne doivent pas être confondus avec les 21,42 Gio disponibles dans le Thin Pool.

### 8.2 Identification du volume physique

**Commande exécutée :**

```bash
pvs
```

**Résultat obtenu :**

```text
  PV         VG  Fmt  Attr PSize   PFree
  /dev/vda3  pve lvm2 a--  <63.50g <7.88g
```

### Explication technique

La commande `pvs` affiche les volumes physiques utilisés par LVM.

Le résultat confirme que :

- `/dev/vda3` est le volume physique LVM.
- Il appartient au groupe `pve`.
- Il possède une capacité d'environ 63,50 Gio.
- Il reste environ 7,88 Gio non alloués.

Le stockage de Proxmox repose donc sur une seule partition LVM située sur le disque virtuel `/dev/vda`.

## 9. Vérification de la surveillance du Thin Pool

### 9.1 Vérification de l'état du monitoring

Pour savoir si le pool Thin est surveillé, nous exécutons :

**Commande exécutée :**

```bash
lvs -o+seg_monitor,segtype,devices pve/data
```

**Résultat obtenu :**

```text
  LV   VG  Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert Monitor   Type      Devices
  data pve twi-a-tz-- 21.42g             0.00   1.58                             monitored thin-pool data_tdata(0)
```

### Explication technique

Les options supplémentaires permettent d'afficher :

- `seg_monitor` : état de surveillance du segment.
- `segtype` : type de segment LVM.
- `devices` : périphérique utilisé.

Le résultat indique :

```text
Monitor: monitored
Type: thin-pool
```

Le pool est donc surveillé par le mécanisme de monitoring LVM.

### 9.2 Vérification de la configuration de l'extension automatique

LVM permet de configurer une extension automatique des Thin Pools lorsque leur taux d'utilisation dépasse un certain seuil.

Pour examiner les paramètres concernés, nous avons exécuté :

**Commande exécutée :**

```bash
lvmconfig --type current activation/thin_pool_autoextend_threshold activation/thin_pool_autoextend_percent
```

**Résultat obtenu :**

```text
  Configuration node activation/thin_pool_autoextend_threshold not found
  Configuration node activation/thin_pool_autoextend_percent not found
```

Cette commande ne retourne pas de valeurs effectives explicites pour ces deux paramètres.

Nous examinons alors le fichier de configuration LVM.

**Commande exécutée :**

```bash
grep -n -A 15 -B 5 "thin_pool_autoextend" /etc/lvm/lvm.conf
```

**Extrait obtenu :**

```text
1756: # Configuration option activation/thin_pool_autoextend_threshold.
1757: # Auto-extend a thin pool when its usage exceeds this percent.
1758: # Setting this to 100 disables automatic extension.
1759: # The minimum value is 50 (a smaller value is treated as 50.)
1760: # Also see thin_pool_autoextend_percent.
1761: # Automatic extension requires dmeventd to be monitoring the LV.
1762:
1763: # Example
1764: # Using 70% autoextend threshold and 20% autoextend size, when a 1G
1765: # thin pool exceeds 700M, it is extended to 1.2G, and when it exceeds
1766: # 840M, it is extended to 1.44G:
1767: # thin_pool_autoextend_threshold = 70
1768:
1769: # This configuration option has an automatic default value.
1770: # thin_pool_autoextend_threshold = 100
1771:
1772: # Configuration option activation/thin_pool_autoextend_percent.
1773: # Auto-extending a thin pool adds this percent extra space.
1774: # The amount of additional space added to a thin pool is this
1775: # percent of its current size.
1776:
1777: # Example
1778: # Using 70% autoextend threshold and 20% autoextend size, when a 1G
1779: # thin pool exceeds 700M, it is extended to 1.2G, and when it exceeds
1780: # 840M, it is extended to 1.44G:
1781: # thin_pool_autoextend_percent = 20
1782:
1783: # This configuration option has an automatic default value.
1784: # thin_pool_autoextend_percent = 20
```

### Explication technique

Deux paramètres sont importants :

**`thin_pool_autoextend_threshold`**

Il définit le pourcentage d'utilisation du Thin Pool à partir duquel LVM doit déclencher une extension automatique.

La valeur par défaut documentée est 100.

Une valeur de 100 désactive l'extension automatique.

**`thin_pool_autoextend_percent`**

Il définit le pourcentage supplémentaire de capacité à ajouter au Thin Pool lorsqu'une extension automatique est déclenchée.

La valeur par défaut documentée est 20.

Dans notre environnement, le seuil de 100 % signifie que l'extension automatique n'est pas activée par défaut.

### 9.3 Vérification du service de surveillance LVM

**Commande exécutée :**

```bash
systemctl status lvm2-monitor.service --no-pager
```

**Résultat obtenu :**

```text
● lvm2-monitor.service - Monitoring of LVM2 mirrors, snapshots etc. using dmeventd or progress polling
     Loaded: loaded (/usr/lib/systemd/system/lvm2-monitor.service; enabled; preset: enabled)
     Active: active (exited)
       Docs: man:dmeventd(8)
             man:lvcreate(8)
             man:lvchange(8)
             man:vgchange(8)
    Process: 307 ExecStart=/usr/sbin/lvm vgchange --monitor y (code=exited, status=0/SUCCESS)
    Main PID: 307 (code=exited, status=0/SUCCESS)

Nov 06 00:39:58 pve1 lvm[307]:   5 logical volume(s) in volume group "pve" monitored
```

Le service est activé et sa dernière exécution s'est terminée avec le code de succès 0.

Il a placé cinq volumes logiques sous surveillance.

**Point important :** la surveillance du Thin Pool et son extension automatique sont deux mécanismes distincts. La présence du monitoring ne signifie pas que l'extension automatique est activée.

### 9.4 Vérification de l'état du périphérique Device Mapper

**Commande exécutée :**

```bash
dmsetup status
```

**Résultat obtenu :**

```text
pve-data: 0 44924928 thin-pool 0 4142/262144 0/350976 - rw discard_passdown queue_if_no_space - 1024
pve-data_tdata: 0 44924928 linear
pve-data_tmeta: 0 2097152 linear
pve-root: 0 55427072 linear
pve-swap: 0 12091392 linear
```

### Explication technique

La commande `dmsetup status` permet de consulter l'état des périphériques gérés par Device Mapper, la couche utilisée par LVM.

La première ligne concerne le pool `pve-data`.

Les informations importantes sont :

- `thin-pool` : indique le type de périphérique.
- `4142/262144` : blocs de métadonnées utilisés par rapport au total.
- `0/350976` : blocs de données utilisés par rapport au total.
- `rw` : périphérique accessible en lecture et en écriture.
- `queue_if_no_space` : comportement de mise en attente des opérations lorsqu'il n'y a plus d'espace disponible dans le pool.

Cette sortie confirme que le pool est actif et que son espace de données n'est pas encore consommé.

## 10. Vérification de la capacité du Thin Pool et des volumes existants

### 10.1 Affichage de la capacité du pool en Gio

Pour obtenir une lecture plus simple de la taille et du taux d'utilisation du pool, nous utilisons :

**Commande exécutée :**

```bash
lvs --units g --nosuffix \
  -o lv_name,lv_size,data_percent,metadata_percent,seg_monitor \
  pve/data
```

**Résultat obtenu :**

```text
  LV   LSize Data%  Meta%  Monitor
  data 21.42 0.00   1.58   monitored
```

La commande confirme :

- Taille du pool : 21,42 Gio.
- Données utilisées : 0 %.
- Métadonnées utilisées : 1,58 %.
- Surveillance : active.

### 10.2 Inventaire des volumes virtuels

Avant de déployer de nouvelles machines virtuelles, nous vérifions si le stockage contient déjà des disques virtuels.

**Commande exécutée :**

```bash
pvesm list local-lvm
```

**Résultat obtenu :**

```text
Volid Format  Type      Size VMID
```

Aucun volume n'est affiché.

Le stockage `local-lvm` ne contient donc actuellement aucun volume enregistré dans l'inventaire Proxmox.

Il est ainsi disponible pour accueillir les futurs disques virtuels.

## 11. Vérification des ressources CPU

Le stockage n'est pas le seul élément à prendre en compte avant le déploiement. Il est également nécessaire de connaître les ressources CPU visibles par Proxmox.

### 11.1 Identification du processeur et de la virtualisation

La commande exécutée est :

```bash
lscpu
```

Les informations obtenues dans la sortie concernent notamment :

```text
Virtualization features:
  Virtualization:            VT-x
  Hypervisor vendor:         KVM
  Virtualization type:       full

NUMA:
  NUMA node(s):              1
  NUMA node0 CPU(s):         0,1
```

### Explication technique

Les résultats montrent :

- `VT-x` : technologie de virtualisation matérielle Intel.
- `KVM` : hyperviseur qui héberge la machine virtuelle Proxmox.
- `full` : virtualisation complète.
- `NUMA node(s): 1` : un seul nœud NUMA est visible.

Les CPU visibles sont les processeurs virtuels attribués à la VM Proxmox.

### 11.2 Vérification du nombre de CPU logiques

**Commande exécutée :**

```bash
nproc
```

**Résultat obtenu :**

```text
2
```

Proxmox dispose donc de deux CPU logiques virtuels.

Cette capacité doit être prise en compte lors du dimensionnement des futures VM.

## 12. Vérification de la mémoire RAM

### 12.1 Analyse de la mémoire disponible

**Commande exécutée :**

```bash
free -h
```

**Résultat obtenu :**

```text
               total        used        free      shared  buff/cache   available
Mem:           5.8Gi       1.4Gi       4.2Gi        32Mi       415Mi       4.3Gi
Swap:          5.8Gi          0B       5.8Gi
```

### Explication technique

La commande `free -h` affiche l'utilisation de la mémoire RAM et de la mémoire swap.

Les indicateurs principaux sont :

- `total` : mémoire totale visible par le système.
- `used` : mémoire actuellement utilisée.
- `free` : mémoire totalement libre.
- `buff/cache` : mémoire utilisée pour les buffers et les caches.
- `available` : estimation de la mémoire disponible pour les nouvelles applications.
- `Swap` : espace d'échange configuré.

Les résultats montrent :

| Indicateur | Valeur |
|---|---:|
| RAM totale | 5,8 Gio |
| RAM utilisée | 1,4 Gio |
| RAM libre | 4,2 Gio |
| RAM disponible | 4,3 Gio |
| Swap totale | 5,8 Gio |
| Swap utilisée | 0 Gio |

Pour dimensionner les futures VM, la valeur `available` est particulièrement utile puisqu'elle représente une estimation de la mémoire qui peut être mise à disposition sans provoquer immédiatement une pression excessive sur la mémoire.

## 13. Identification de la virtualisation imbriquée

### 13.1 Identification de l'hyperviseur

Afin de confirmer si Proxmox fonctionne sur une machine physique ou virtuelle, nous exécutons :

**Commande exécutée :**

```bash
systemd-detect-virt
```

**Résultat obtenu :**

```text
kvm
```

Ce résultat confirme que Proxmox VE est exécuté dans une machine virtuelle KVM.

Notre architecture correspond donc à une virtualisation imbriquée :

```text
HÔTE PHYSIQUE
     |
     v
KVM / QEMU
     |
     v
VM PROXMOX VE 9.2.25
     |
     +--------------------------+
     |                          |
     v                          v
  Stockage                  Ressources
  LVM-Thin                  CPU / RAM
     |                          |
     +-------------+------------+
                   |
                   v
          FUTURES MACHINES VM
             DÉPLOYÉES PAR
               TERRAFORM
```

### 13.2 Vérification de la mémoire déclarée par QEMU

**Commande exécutée :**

```bash
dmidecode -t memory
```

**Résultat obtenu :**

```text
# dmidecode 3.6
Getting SMBIOS data from sysfs.
SMBIOS 3.0.0 present.

Handle 0x1000, DMI type 16, 23 bytes
Physical Memory Array
    Location: Other
    Use: System Memory
    Error Correction Type: Multi-bit ECC
    Maximum Capacity: 6 GB
    Error Information Handle: Not Provided
    Number Of Devices: 1

Handle 0x1100, DMI type 17, 40 bytes
Memory Device
    Array Handle: 0x1000
    Error Information Handle: Not Provided
    Total Width: Unknown
    Data Width: Unknown
    Size: 6 GB
    Form Factor: DIMM
    Set: None
    Locator: DIMM 0
    Bank Locator: Not Specified
    Type: RAM
    Type Detail: Other
    Speed: Unknown
    Manufacturer: QEMU
```

### Explication technique

La commande `dmidecode` permet de consulter les informations SMBIOS présentées au système.

Le résultat indique :

- Fabricant du périphérique mémoire : QEMU.
- Taille déclarée : 6 Go.
- Nombre de périphériques mémoire : 1.
- Capacité maximale déclarée : 6 Go.

Cela confirme que la mémoire RAM visible par Proxmox est une mémoire virtuelle attribuée par QEMU.

### 13.3 Vérification complémentaire avec /proc/meminfo

**Commande exécutée :**

```bash
cat /proc/meminfo | head -15
```

**Résultat obtenu :**

```text
MemTotal:        6046876 kB
MemFree:         4394452 kB
MemAvailable:    4550752 kB
Buffers:           22060 kB
Cached:            382200 kB
SwapCached:            0 kB
Active:          1303904 kB
Inactive:          90292 kB
Active(anon):    1032108 kB
Inactive(anon):        0 kB
Active(file):     271796 kB
Inactive(file):    90292 kB
Unevictable:       26296 kB
Mlocked:           22296 kB
SwapTotal:       6045692 kB
```

Cette commande permet d'accéder aux statistiques détaillées de la mémoire exposées par le noyau Linux.

Les valeurs `MemTotal`, `MemFree` et `MemAvailable` confirment les informations obtenues précédemment avec `free -h`.

La mémoire totale visible est d'environ 5,77 Gio, soit approximativement 6 Go attribués à la VM Proxmox.

## 14. Synthèse générale de l'audit

Après l'ensemble des vérifications, nous obtenons la configuration suivante.

### 14.1 Synthèse du stockage

| Indicateur | Valeur |
|---|---:|
| Disque virtuel principal | 64 Gio |
| Stockage `local` | 25,85 Gio |
| Espace disponible `local` | 19,18 Gio |
| Stockage `local-lvm` | 21,42 Gio |
| Données utilisées dans le Thin Pool | 0 % |
| Métadonnées utilisées | 1,58 % |
| Espace LVM non alloué | 7,88 Gio |
| Volumes virtuels présents dans `local-lvm` | Aucun |

### 14.2 Synthèse des ressources matérielles

| Ressource | Valeur |
|---|---:|
| Hyperviseur sous-jacent | KVM / QEMU |
| CPU logiques attribués | 2 |
| RAM attribuée | 6 Go |
| RAM disponible | 4,3 Gio |
| Swap | 5,8 Gio |
| Disque virtuel | 64 Gio |

### 14.3 État des mécanismes de surveillance

| Élément | État constaté |
|---|---|
| Stockage `local` | Actif |
| Stockage `local-lvm` | Actif |
| Pool LVM-Thin | Actif |
| Monitoring LVM | Actif |
| Service `lvm2-monitor` | Activé |
| Extension automatique du Thin Pool | Désactivée par défaut |
| Volumes VM dans `local-lvm` | Aucun |

## 15. Recommandations pour le déploiement Terraform

L'audit confirme que l'infrastructure dispose d'une capacité de stockage et de ressources suffisantes pour commencer un premier déploiement de test, sous réserve d'un dimensionnement prudent.

### 15.1 Organisation des stockages

La répartition proposée est la suivante :

| Stockage | Utilisation prévue |
|---|---|
| `local` | Images ISO, templates et sauvegardes |
| `local-lvm` | Disques des futures machines virtuelles |
| Réserve LVM non allouée | Marge disponible pour une éventuelle extension |

### 15.2 Dimensionnement initial d'une VM de test

Pour le premier déploiement, nous proposons le dimensionnement indicatif suivant :

| Ressource | Valeur proposée |
|---|---:|
| CPU | 1 vCPU |
| RAM | 1 Gio |
| Disque | 8 Gio |
| Stockage | `local-lvm` |

Ces valeurs constituent une proposition de départ et devront être adaptées au système d'exploitation invité et à ses besoins réels.

### 15.3 Précautions concernant le Thin Provisioning

Le Thin Provisioning permet de créer des disques virtuels dont la capacité logique peut être supérieure à l'espace physique immédiatement consommé.

Il ne faut cependant pas confondre :

- La capacité virtuelle attribuée aux VM.
- L'espace physique réellement consommé dans le Thin Pool.

Si les VM consomment davantage d'espace que le Thin Pool ne peut en fournir, des problèmes d'écriture et de fonctionnement peuvent apparaître.

Il est donc nécessaire de surveiller régulièrement les indicateurs `Data%` et `Meta%`.

De même, la réserve de 7,88 Gio dans le groupe LVM doit être préservée autant que possible. Une extension du Thin Pool ne doit être envisagée qu'après étude de l'espace disponible et des besoins futurs.

## 16. Conclusion

L'audit du stockage et des ressources de Proxmox VE 9.2.25 est terminé.

Les vérifications ont permis de confirmer que :

- Les stockages `local` et `local-lvm` sont actifs.
- Le stockage local dispose d'environ 19,18 Gio disponibles.
- Le pool LVM-Thin dispose d'environ 21,42 Gio de capacité.
- Aucune donnée virtuelle n'est actuellement utilisée dans le Thin Pool.
- Les métadonnées du Thin Pool sont utilisées à hauteur de 1,58 %.
- Le groupe LVM conserve environ 7,88 Gio non alloués.
- Le mécanisme de surveillance LVM est actif.
- L'extension automatique du Thin Pool est désactivée par défaut.
- Aucun volume virtuel n'est actuellement enregistré dans `local-lvm`.
- Proxmox dispose de 2 CPU logiques et de 6 Go de RAM attribués par KVM.

**Décision :** conserver la configuration actuelle sans modification du stockage pour le moment et utiliser `local-lvm` pour les disques des futures machines virtuelles Terraform.

La prochaine étape du projet consistera à préparer le provider Terraform Proxmox, vérifier la communication avec l'API et réaliser un premier déploiement contrôlé.

---

### 17. Comprendre quel stockage est impacté lors du déploiement d'une VM

Dans notre architecture, Proxmox VE dispose d'un disque virtuel principal de 64 Gio (`/dev/vda`), fourni par l'hyperviseur KVM/QEMU.

Ce disque contient une partition LVM (`/dev/vda3`) dans laquelle se trouve le groupe de volumes `pve`.

Lorsqu'une machine virtuelle est créée, le stockage physique sollicité dépend du stockage sélectionné dans Proxmox.

**Cas 1 : utilisation de `local-lvm`**

Lorsque le stockage `local-lvm` est sélectionné pour le disque de la VM, Proxmox crée un volume virtuel dans le Thin Pool `pve/data`.

L'espace physique consommé est alors prélevé dans le pool LVM-Thin de 21,42 Gio.

Le volume concerné est donc `pve-data`, situé sur la partition `/dev/vda3` du disque virtuel `/dev/vda`.

**Cas 2 : utilisation de `local`**

Lorsque le stockage `local` est sélectionné pour le disque de la VM, Proxmox crée généralement un fichier disque dans le répertoire :

```text
/var/lib/vz/images/
```

Ce répertoire se trouve sur le système de fichiers racine `/`, associé au volume logique `pve-root`.

Dans ce cas, c'est l'espace disponible du stockage `local` qui est consommé.

**Synthèse :**

| Stockage sélectionné | Emplacement | Volume sollicité |
|---|---|---|
| `local-lvm` | Pool LVM-Thin `pve/data` | `pve-data` |
| `local` | `/var/lib/vz/images/` | `pve-root` |

**Décision pour notre projet Terraform :**

Nous utiliserons principalement `local-lvm` pour stocker les disques des machines virtuelles. Le stockage `local` sera réservé aux images ISO, aux templates et aux sauvegardes.

Ainsi, les disques des futures VM seront isolés du système de fichiers racine de Proxmox au niveau de l'organisation du stockage, tout en restant hébergés sur le même disque virtuel `/dev/vda`.

Il est important de retenir que ces deux stockages ne correspondent pas à deux disques physiques indépendants : ils reposent tous les deux sur le même disque virtuel de 64 Gio.

**Fin de la section 09 — Audit du stockage et vérification des ressources de Proxmox VE.**