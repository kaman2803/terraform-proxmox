# 12 — Détection du nouveau disque et extension du stockage LVM-Thin dans Proxmox VE

## 12.1. Objectif de l'opération

À la fin de la section précédente, le disque virtuel de la machine Proxmox VE avait été agrandi de 64 Gio à 96 Gio depuis l'hôte KVM/QEMU.

Cependant, l'augmentation de la taille du disque virtuel ne signifie pas automatiquement que Proxmox peut exploiter cet espace supplémentaire.

Il est nécessaire de faire évoluer successivement plusieurs couches de stockage :

1. Le disque virtuel QCOW2, hébergé sur l'hôte KVM.
2. La table de partitions GPT du disque `/dev/vda`.
3. La partition `/dev/vda3`, qui contient le volume physique LVM.
4. Le groupe de volumes LVM `pve`.
5. Le thin pool `pve/data`, utilisé par Proxmox pour stocker les disques des machines virtuelles.

L'objectif est d'obtenir un thin pool d'environ 53,42 Gio afin de disposer d'une capacité suffisante pour les deux machines virtuelles Ubuntu Server 24.04 LTS prévues dans le projet :

| Machine virtuelle | Système | CPU | RAM | Disque |
|---|---|---:|---:|---:|
| srv01 | Ubuntu Server 24.04 LTS | 1 vCPU | 1 Gio | 15 Gio |
| srv02 | Ubuntu Server 24.04 LTS | 1 vCPU | 1 Gio | 15 Gio |

La capacité totale prévue pour leurs disques est donc de 30 Gio.

## 12.2. Démarrage de la machine Proxmox VE

Après l'extension du disque QCOW2 à 96 Gio dans la section 11, la machine virtuelle Proxmox était arrêtée.

Depuis l'hôte KVM `Kgoumou`, nous avons redémarré la machine :

```bash
virsh start pve1
```

Résultat :

```text
Domain 'pve1' started
```

Nous avons ensuite vérifié son état :

```bash
virsh list --all
```

La machine `pve1` apparaissait en état `running`. Les machines `oracle-db-server` et `win10-lab` étaient arrêtées.

**Explication technique :**

La commande `virsh start` démarre une machine virtuelle gérée par libvirt. Le démarrage de Proxmox permet au système invité de détecter la nouvelle capacité du disque virtuel présentée par QEMU.

## 12.3. Détection de la nouvelle capacité du disque

Sur Proxmox VE, nous avons exécuté :

```bash
lsblk
```

Résultat :

```text
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda                253:0    0   96G  0 disk
├─vda1             253:1    0 1007K  0 part
├─vda2             253:2    0  512M  0 part /boot/efi
└─vda3             253:3    0  63.5G  0 part
  ├─pve-swap       252:0    0  5.8G  0 lvm  [SWAP]
  ├─pve-root       252:1    0 26.4G  0 lvm  /
  ├─pve-data_tmeta 252:2    0    1G  0 lvm
  │ └─pve-data     252:4    0 21.4G  0 lvm
  └─pve-data_tdata 252:3    0 21.4G  0 lvm
    └─pve-data     252:4    0 21.4G  0 lvm
```

**Analyse :**

Le disque `/dev/vda` est bien passé à 96 Gio. Toutefois, la partition `/dev/vda3` est toujours de 63,5 Gio.

Cela signifie que l'espace supplémentaire de 32 Gio est détecté au niveau du disque, mais qu'il n'est pas encore attribué à la partition contenant LVM.

La structure existante est la suivante :

- `/dev/vda1` : partition BIOS boot.
- `/dev/vda2` : partition EFI de 512 Mio.
- `/dev/vda3` : partition Linux LVM contenant le système Proxmox et le stockage des machines virtuelles.

## 12.4. Vérification et correction de la table GPT

Nous avons examiné la structure du disque :

```bash
fdisk -l /dev/vda
```

Le disque était détecté avec une capacité de 96 Gio, mais affichait notamment :

```text
GPT PMBR size mismatch (134217727 != 201326591)
```

**Explication technique :**

La GPT (GUID Partition Table) conserve une table principale au début du disque et une copie de sauvegarde à sa fin.

Après l'agrandissement du disque QCOW2, les métadonnées GPT secondaires n'étaient plus positionnées à la nouvelle fin du disque.

Nous avons vérifié la table :

```bash
sgdisk -v /dev/vda
```

Puis corrigé l'emplacement des métadonnées GPT secondaires :

```bash
sgdisk -e /dev/vda
```

Résultat :

```text
Warning: The kernel is still using the old partition table.
The new table will be used at the next reboot or after you
run partprobe(8) or kpartx(8)
The operation has completed successfully.
```

Nous avons effectué une nouvelle vérification :

```bash
sgdisk -v /dev/vda
```

Résultat :

```text
Caution: Partition 3 doesn't end on a 2-sector boundary.
No problems found. 67108864 free sectors (32.0 GiB) available in 1 segments.
```

**Explication technique :**

L'option `-e` de `sgdisk` déplace les structures GPT secondaires à la nouvelle fin du disque. La vérification confirme que la GPT ne présente plus de problème bloquant et que 32 Gio sont disponibles.

## 12.5. Préparation de l'extension de la partition

Nous avons tenté de recharger la table de partitions avec :

```bash
partprobe /dev/vda
```

Mais la commande n'était pas installée :

```text
-bash: partprobe: command not found
```

Nous avons également vérifié la disponibilité de `kpartx`, qui n'était pas présent.

Nous avons contrôlé la taille du disque et les informations de la partition directement dans le noyau :

```bash
blockdev --getsize64 /dev/vda
```

Résultat :

```text
103079215104
```

Puis :

```bash
cat /sys/class/block/vda/size
```

Résultat :

```text
201326592
```

Nous avons également vérifié le secteur de début de `/dev/vda3` :

```bash
cat /sys/class/block/vda3/start
```

Résultat :

```text
1050624
```

Et sa taille :

```bash
cat /sys/class/block/vda3/size
```

Résultat :

```text
133167071
```

La partition conservait donc son ancienne taille.

## 12.6. Installation de l'outil growpart

Pour agrandir la partition sans la supprimer et la recréer manuellement, nous avons choisi `growpart`.

Cet outil est fourni par le paquet Debian `cloud-guest-utils`.

Nous avons vérifié sa disponibilité :

```bash
apt-cache policy cloud-guest-utils
```

Résultat :

```text
cloud-guest-utils:
  Installed: (none)
  Candidate: 0.33-1
  Version table:
     0.33-1 500
        500 http://deb.debian.org/debian trixie/main amd64 Packages
```

Après l'installation du paquet, nous avons vérifié la disponibilité de la commande :

```bash
command -v growpart
```

Résultat :

```text
/usr/bin/growpart
```

**Explication technique :**

`growpart` permet d'agrandir une partition existante pour qu'elle utilise l'espace libre disponible sur le disque. Son intérêt ici est de conserver le secteur de début de `/dev/vda3`, qui contient le volume physique LVM actif.

## 12.7. Simulation de l'extension avec growpart

Avant de modifier réellement la partition, nous avons utilisé le mode simulation :

```bash
growpart -N /dev/vda 3
```

Résultat :

```text
CHANGE: partition=3 start=1050624 old: size=133167071 end=134217694 new: size=200275935 end=201326558
```

**Analyse technique :**

| Paramètre | Ancienne valeur | Nouvelle valeur prévue |
|---|---:|---:|
| Partition | 3 | 3 |
| Secteur de début | 1 050 624 | 1 050 624 |
| Taille en secteurs | 133 167 071 | 200 275 935 |
| Secteur de fin | 134 217 694 | 201 326 558 |

Le secteur de début reste identique. La taille augmente pour exploiter l'espace libre disponible jusqu'à la fin du disque.

L'option `-N` permet de simuler l'opération sans modifier la table de partitions.

## 12.8. Extension effective de la partition /dev/vda3

La simulation étant conforme, nous avons exécuté :

```bash
growpart /dev/vda 3
```

Résultat :

```text
CHANGED: partition=3 start=1050624 old: size=133167071 end=134217694 new: size=200275935 end=201326558
```

Le message `CHANGED` confirme que la partition a été modifiée.

**Explication technique :**

La commande `growpart` a modifié la table GPT afin d'augmenter la limite de la partition 3. Elle n'a pas déplacé son secteur de début et n'a pas supprimé les volumes LVM existants.

## 12.9. Vérification de la nouvelle taille de la partition

Nous avons vérifié la structure avec :

```bash
lsblk
```

Résultat :

```text
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda                253:0    0   96G  0 disk
├─vda1             253:1    0 1007K  0 part
├─vda2             253:2    0  512M  0 part /boot/efi
└─vda3             253:3    0 95.5G  0 part
  ├─pve-swap       252:0    0  5.8G  0 lvm  [SWAP]
  ├─pve-root       252:1    0 26.4G  0 lvm  /
  ├─pve-data_tmeta 252:2    0    1G  0 lvm
  │ └─pve-data     252:4    0 21.4G  0 lvm
  └─pve-data_tdata 253:3    0 21.4G  0 lvm
    └─pve-data     252:4    0 21.4G  0 lvm
```

Nous avons également vérifié sa taille en octets :

```bash
blockdev --getsize64 /dev/vda3
```

Résultat :

```text
102541278720
```

Puis sa taille en secteurs :

```bash
cat /sys/class/block/vda3/size
```

Résultat :

```text
200275935
```

Ces valeurs confirment que le noyau Linux a bien pris en compte la nouvelle taille de la partition. Aucun redémarrage supplémentaire n'a été nécessaire.

## 12.10. Vérification du volume physique et du groupe de volumes LVM

Nous avons contrôlé les ressources LVM :

```bash
pvs --units g
```

Résultat :

```text
PV         VG  Fmt  Attr PSize  PFree
/dev/vda3  pve lvm2 a--  95.50g 39.88g
```

Puis :

```bash
vgs --units g
```

Résultat :

```text
VG  #PV #LV #SN Attr   VSize  VFree
pve   1   3   0 wz--n- 95.50g 39.88g
```

**Explication technique :**

LVM repose sur plusieurs niveaux :

- **PV (Physical Volume)** : volume physique initialisé pour LVM. Ici, `/dev/vda3`.
- **VG (Volume Group)** : groupe de volumes qui rassemble un ou plusieurs PV. Ici, `pve`.
- **LV (Logical Volume)** : volume logique créé à partir de l'espace disponible dans le VG.

Les résultats montrent que LVM reconnaît déjà une taille de 95,50 Gio pour le PV et le VG, avec 39,88 Gio libres.

Il n'a donc pas été nécessaire d'exécuter `pvresize` : l'extension du PV était déjà prise en compte.

## 12.11. Analyse du thin pool avant extension

Nous avons examiné les volumes logiques :

```bash
lvs -a --units g -o lv_name,lv_size,lv_attr,data_percent,metadata_percent pve
```

Résultat :

```text
LV              LSize  Attr       Data%  Meta%
data            21.42g twi-a-tz-- 0.00   1.58
[data_tdata]    21.42g Twi-ao----
[data_tmeta]     1.00g ewi-ao----
[lvol0_pmspare]  1.00g ewi-------
root            26.43g -wi-ao----
swap             5.77g -wi-ao----
```

**Explication technique :**

Le thin pool `pve/data` est constitué de deux composants :

- `data_tdata` : contient les blocs de données des volumes virtuels.
- `data_tmeta` : contient les métadonnées qui assurent le suivi de l'allocation des blocs dans le thin pool.

Les colonnes `Data%` et `Meta%` indiquent respectivement le taux d'utilisation des données et des métadonnées.

Avant extension :

- Capacité du thin pool : 21,42 Gio.
- Utilisation des données : 0 %.
- Utilisation des métadonnées : 1,58 %.
- Espace libre dans le VG : 39,88 Gio.

## 12.12. Extension du thin pool LVM

Le dimensionnement retenu consiste à ajouter 32 Gio au thin pool.

La capacité cible est donc :

21,42 Gio + 32 Gio = 53,42 Gio.

Nous avons exécuté :

```bash
lvextend -L +32G pve/data
```

Résultat :

```text
Size of logical volume pve/data_tdata changed from 21.42 GiB (5484 extents) to 53.42 GiB (13676 extents).
Logical volume pve/data successfully resized.
```

**Explication technique :**

La commande `lvextend` permet d'augmenter la taille d'un volume logique.

- `-L` : indique une taille exprimée en unités lisibles par l'utilisateur.
- `+32G` : demande d'ajouter 32 Gio à la taille existante.
- `pve/data` : désigne le thin pool à étendre.

L'opération a augmenté le composant de données `data_tdata`, qui est passé de 21,42 Gio à 53,42 Gio. Le volume de métadonnées est resté à 1 Gio.

## 12.13. Vérification finale du thin pool et du VG

Après l'extension, nous avons contrôlé les volumes logiques :

```bash
lvs -a --units g -o lv_name,lv_size,lv_attr,data_percent,metadata_percent pve
```

Résultat :

```text
LV              LSize  Attr       Data%  Meta%
data            53.42g twi-a-tz-- 0.00   1.59
[data_tdata]    53.42g Twi-ao----
[data_tmeta]     1.00g ewi-ao----
[lvol0_pmspare]  1.00g ewi-------
root            26.43g -wi-ao----
swap             5.77g -wi-ao----
```

Le thin pool dispose maintenant de 53,42 Gio. Son utilisation des données est toujours de 0 %, tandis que les métadonnées sont utilisées à hauteur de 1,59 %.

Nous avons ensuite vérifié le groupe de volumes :

```bash
vgs --units g
```

Résultat :

```text
VG  #PV #LV #SN Attr   VSize  VFree
pve   1   3   0 wz--n- 95.50g 7.88g
```

Le groupe de volumes conserve 7,88 Gio libres.

## 12.14. Validation dans Proxmox

Pour terminer, nous avons vérifié que Proxmox reconnaissait la nouvelle capacité :

```bash
pvesm status
```

Résultat :

```text
Name             Type     Status     Total (KiB)      Used (KiB) Available (KiB)        %
local             dir     active        27102164         5594928        20105176   20.64%
local-lvm     lvmthin     active        56016896               0        56016896    0.00%
```

**Explication technique :**

La commande `pvesm status` affiche l'état des stockages configurés dans Proxmox.

- `local` : stockage de type `dir`, utilisé notamment pour les ISO, les templates et les sauvegardes.
- `local-lvm` : stockage de type `lvmthin`, utilisé pour les disques des machines virtuelles et des conteneurs.

Le stockage `local-lvm` affiche une capacité totale de 56 016 896 Kio, soit environ 53,42 Gio. Son statut est `active` et son utilisation est de 0 %.

Cela confirme que Proxmox reconnaît correctement la nouvelle capacité du thin pool.

## 12.15. Bilan final de l'opération

L'extension du stockage Proxmox VE est terminée.

| Élément | Avant | Après |
|---|---:|---:|
| Disque QCOW2 de Proxmox | 64 Gio | 96 Gio |
| Partition `/dev/vda3` | 63,5 Gio | 95,5 Gio |
| Volume physique LVM | 63,50 Gio | 95,50 Gio |
| Groupe de volumes `pve` | 63,50 Gio | 95,50 Gio |
| Thin pool `pve/data` | 21,42 Gio | 53,42 Gio |
| Espace libre dans le VG | 7,88 Gio avant extension | 7,88 Gio après extension du thin pool |

La capacité de stockage disponible dans `local-lvm` est maintenant d'environ 53,42 Gio.

Cette capacité est suffisante pour accueillir les deux disques virtuels de 15 Gio prévus pour `srv01` et `srv02`, sous réserve de surveiller l'espace physique réellement consommé par les machines virtuelles.

**À retenir :** le stockage LVM-Thin fonctionne en allocation dynamique. La capacité logique attribuée aux disques virtuels ne correspond pas nécessairement à une consommation physique immédiate équivalente. L'espace physique est consommé progressivement lorsque les données sont écrites.

## 12.16. Conclusion

Cette section a permis de rendre exploitable l'espace supplémentaire de 32 Gio ajouté au disque virtuel de Proxmox VE.

L'opération a nécessité la correction des métadonnées GPT, l'extension de la partition `/dev/vda3`, puis l'augmentation du thin pool LVM.

La vérification finale avec `lvs`, `vgs` et `pvesm status` confirme que le stockage `local-lvm` est actif et dispose désormais d'environ 53,42 Gio.

La plateforme Proxmox est ainsi préparée pour la prochaine phase du projet : la préparation d'une image Ubuntu Server 24.04 LTS et le déploiement automatisé des machines virtuelles avec Terraform.

## 12.17. Fiche récapitulative — Étapes et commandes essentielles

Cette fiche reprend le cheminement technique de l'extension, depuis le disque virtuel QCOW2 jusqu'à son exploitation par Proxmox. Elle constitue une référence rapide pour comprendre et reproduire l'opération.

### A. Au niveau de l'hôte KVM/QEMU

**1. Arrêter la machine virtuelle Proxmox :**

```bash
virsh shutdown pve1
```

**2. Vérifier son arrêt :**

```bash
virsh list --all
```

**3. Sauvegarder le disque QCOW2 avant modification :**

```bash
sudo cp --sparse=always --reflink=auto \
/var/lib/libvirt/images/pve1.qcow2 \
~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

**4. Vérifier l'intégrité de la copie :**

```bash
sudo sha256sum \
/var/lib/libvirt/images/pve1.qcow2 \
~/lab/kvm/templates/pve1-backup/pve1-backup.qcow2
```

Les deux empreintes doivent être identiques.

**5. Agrandir le disque virtuel :**

```bash
sudo qemu-img resize /var/lib/libvirt/images/pve1.qcow2 96G
```

**6. Redémarrer Proxmox :**

```bash
virsh start pve1
```

### B. Au niveau de Proxmox — GPT et partition

**1. Examiner le disque et les partitions :**

```bash
lsblk
fdisk -l /dev/vda
```

**2. Vérifier et repositionner les métadonnées GPT secondaires :**

```bash
sgdisk -v /dev/vda
sgdisk -e /dev/vda
sgdisk -v /dev/vda
```

**3. Installer l'outil d'extension de partition, s'il est absent :**

```bash
apt update
apt install cloud-guest-utils
```

**4. Vérifier la présence de growpart :**

```bash
command -v growpart
```

**5. Simuler l'extension de la troisième partition :**

```bash
growpart -N /dev/vda 3
```

**6. Appliquer l'extension :**

```bash
growpart /dev/vda 3
```

**7. Vérifier que le noyau reconnaît la nouvelle taille :**

```bash
lsblk
blockdev --getsize64 /dev/vda3
cat /sys/class/block/vda3/size
```

### C. Au niveau de LVM

**1. Examiner le volume physique et le groupe de volumes :**

```bash
pvs --units g
vgs --units g
```

Dans notre opération, LVM reconnaissait déjà le PV de 95,50 Gio. Aucun `pvresize` n'a donc été nécessaire.

**2. Examiner le thin pool avant son extension :**

```bash
lvs -a --units g \
-o lv_name,lv_size,lv_attr,data_percent,metadata_percent pve
```

**3. Ajouter 32 Gio au thin pool :**

```bash
lvextend -L +32G pve/data
```

**4. Vérifier les volumes logiques et leur utilisation :**

```bash
lvs -a --units g \
-o lv_name,lv_size,lv_attr,data_percent,metadata_percent pve
```

**5. Vérifier l'espace libre restant dans le groupe de volumes :**

```bash
vgs --units g
```

### D. Au niveau de Proxmox — Exploitation du stockage

**1. Vérifier les stockages déclarés et leur état :**

```bash
pvesm status
```

**2. Lister les volumes présents dans le stockage LVM-Thin :**

```bash
pvesm list local-lvm
```

Cette dernière commande permet d'identifier les volumes enregistrés dans `local-lvm`. Elle ne crée pas de disque et ne modifie pas le stockage.

**3. Exploiter le stockage depuis l'interface Web Proxmox :**

- Ouvrir le nœud `pve1`.
- Accéder à `Disks` puis `LVM-Thin` pour examiner le thin pool.
- Accéder à `Datacenter` puis `Storage` pour vérifier la configuration de `local-lvm`.
- Lors de la création d'une VM, sélectionner `local-lvm` comme stockage du disque virtuel.

### E. Résultat attendu dans ce projet

| Élément | Capacité finale |
|---|---:|
| Disque virtuel QCOW2 de Proxmox | 96 Gio |
| Partition `/dev/vda3` | 95,5 Gio |
| PV `/dev/vda3` | 95,50 Gio |
| Groupe de volumes `pve` | 95,50 Gio |
| Thin pool `pve/data` | 53,42 Gio |
| Réserve libre dans le VG | 7,88 Gio |
| Stockage Proxmox `local-lvm` | Environ 53,42 Gio |

**Attention aux niveaux de stockage :** l'extension du disque QCOW2 ne suffit pas à agrandir le thin pool. Chaque couche doit reconnaître et exploiter l'espace ajouté avant que Proxmox puisse l'utiliser pour ses machines virtuelles.

**Fin de la section 12 — Extension du stockage LVM-Thin dans Proxmox VE.**