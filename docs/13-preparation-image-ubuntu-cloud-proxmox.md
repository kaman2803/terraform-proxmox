# Section 13 — Préparation et transfert de l’image Ubuntu Cloud Image pour Terraform

## 13.1. Objectif

Dans cette étape, nous préparons l’image système qui servira de base au déploiement des machines virtuelles Ubuntu Server 24.04 LTS avec Terraform sur Proxmox VE.

Le principe retenu est de permettre à Terraform de créer directement les machines virtuelles à partir d’une image Ubuntu Cloud Image, en utilisant Cloud-Init pour leur configuration initiale.

**Architecture retenue :**
- Aucun template Proxmox préexistant.
- Aucune machine virtuelle de référence.
- Une image Ubuntu Cloud Image téléchargée et vérifiée.
- Un déploiement direct des VM `srv01` et `srv02` avec Terraform.

## 13.2. Création du répertoire de travail pour l’image

Sur la machine Ubuntu `Kgoumou`, nous utilisons le répertoire de travail Terraform :

```bash
cd ~/lab/terraform-proxmox
```

Création du répertoire destiné à stocker les images :

```bash
mkdir -p images
```

Accès au répertoire :

```bash
cd images
```

## 13.3. Téléchargement de l’image Ubuntu Server 24.04 LTS

Nous téléchargeons l’image officielle Ubuntu Cloud Image depuis le serveur de publication Ubuntu :

```bash
wget https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img
```

Vérification du fichier téléchargé :

```bash
ls -lh
```

Résultat obtenu :

```text
total 593M
-rw-rw-r-- 1 kaman-goumou kaman-goumou 593M Oct 17 20:31 ubuntu-24.04-server-cloudimg-amd64.img
```

L’image téléchargée occupe environ 593 Mio sur le disque.

## 13.4. Vérification de l'intégrité de l'image

Afin de vérifier que le fichier téléchargé n'a pas été altéré, nous récupérons le fichier officiel contenant les sommes de contrôle SHA256 :

```bash
wget https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS
```

La somme de contrôle officielle de l’image est :

```text
04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94 *ubuntu-24.04-server-cloudimg-amd64.img
```

Calcul de la somme SHA256 du fichier local :

```bash
sha256sum ubuntu-24.04-server-cloudimg-amd64.img
```

Résultat obtenu :

```text
04e8f2461a16a44e78a370284471f29616cdd9baf1893df25807b71f985b6c94  ubuntu-24.04-server-cloudimg-amd64.img
```

**Conclusion :** les deux sommes SHA256 sont identiques. L’intégrité de l’image téléchargée est donc confirmée.

## 13.5. Vérification du format de l’image sur Kgoumou

Avant le transfert vers Proxmox, nous vérifions les caractéristiques du disque avec `qemu-img` :

```bash
qemu-img info ubuntu-24.04-server-cloudimg-amd64.img
```

Résultat obtenu :

```text
image: ubuntu-24.04-server-cloudimg-amd64.img
file format: qcow2
virtual size: 3.5 GiB (3758096384 bytes)
disk size: 593 MiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: ubuntu-24.04-server-cloudimg-amd64.img
    protocol type: file
    file length: 593 MiB (621284352 bytes)
    disk size: 593 MiB
```

Les informations importantes sont :

- Format : QCOW2.
- Taille virtuelle : 3,5 Gio.
- Taille réelle : 593 Mio.
- Version de compatibilité : 1.1.
- État de corruption : `false`.

L’image est donc reconnue comme un disque QCOW2 valide.

## 13.6. Vérification de la connectivité SSH vers Proxmox

Avant le transfert, nous vérifions la connexion SSH depuis `Kgoumou` vers le serveur Proxmox :

```bash
ssh root@192.168.122.32
```

La connexion SSH a fonctionné. Nous pouvons donc transférer le fichier vers Proxmox.

## 13.7. Préparation du répertoire de destination sur Proxmox

La première tentative de transfert vers le chemin suivant :

```text
/var/lib/vz/template/qemu/
```

a échoué, car le répertoire `qemu` n’existait pas.

Vérification sur Proxmox :

```bash
ls -ld /var/lib/vz/template/
ls -ld /var/lib/vz/template/qemu/
```

Résultat obtenu :

```text
drwxr-xr-x 4 root root 4096 Nov  3 10:25 /var/lib/vz/template/
ls: cannot access '/var/lib/vz/template/qemu/': No such file or directory
```

Nous créons donc le répertoire de destination :

```bash
mkdir -p /var/lib/vz/template/qemu
```

Vérification :

```bash
ls -ld /var/lib/vz/template/qemu/
```

Résultat obtenu :

```text
drwxr-xr-x 2 root root 4096 Nov  6 02:31 /var/lib/vz/template/qemu/
```

Le répertoire est maintenant disponible sur Proxmox.

## 13.8. Transfert de l’image vers Proxmox

Depuis le répertoire `images` de `Kgoumou`, nous lançons le transfert avec SCP :

```bash
scp ubuntu-24.04-server-cloudimg-amd64.img \
root@192.168.122.32:/var/lib/vz/template/qemu/
```

Le transfert s’est terminé avec succès.

Sur Proxmox, nous vérifions la présence du fichier :

```bash
ls -lh /var/lib/vz/template/qemu/
```

Résultat obtenu :

```text
total 593M
-rw-r--r-- 1 root root 593M Nov  6 02:32 ubuntu-24.04-server-cloudimg-amd64.img
```

L’image est bien présente sur le serveur Proxmox.

## 13.9. Vérification finale de l’image sur Proxmox

Nous effectuons une dernière vérification directement sur le serveur Proxmox :

```bash
qemu-img info /var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img
```

Résultat obtenu :

```text
image: /var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img
file format: qcow2
virtual size: 3.5 GiB (3758096384 bytes)
disk size: 593 MiB
cluster_size: 65536
Format specific information:
    compat: 1.1
    compression type: zlib
    lazy refcounts: false
    refcount bits: 16
    corrupt: false
    extended l2: false
Child node '/file':
    filename: /var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img
    protocol type: file
    file length: 593 MiB (621284352 bytes)
    disk size: 593 MiB
```

Les caractéristiques constatées sur Proxmox correspondent à celles vérifiées sur `Kgoumou`. L’image est reconnue au format QCOW2 et l’indicateur `corrupt` vaut `false`.

## Conclusion

La préparation de l’image Ubuntu Cloud Image est terminée.

Les opérations suivantes ont été réalisées avec succès :

1. Téléchargement de l’image officielle Ubuntu Server 24.04 Cloud Image.
2. Vérification de son intégrité avec SHA256.
3. Vérification de son format QCOW2 sur `Kgoumou`.
4. Vérification de la connectivité SSH vers Proxmox.
5. Création du répertoire de destination sur Proxmox.
6. Transfert de l’image avec SCP.
7. Vérification finale de l’image directement sur Proxmox.

L’image est maintenant disponible sur le serveur Proxmox à l’emplacement :

```text
/var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img
```

### Récapitulatif des commandes essentielles

| Opération | Commande |
|---|---|
| Télécharger l’image | `wget https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img` |
| Télécharger les sommes SHA256 | `wget https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS` |
| Vérifier l’intégrité | `sha256sum ubuntu-24.04-server-cloudimg-amd64.img` |
| Examiner l’image | `qemu-img info ubuntu-24.04-server-cloudimg-amd64.img` |
| Créer le répertoire distant | `mkdir -p /var/lib/vz/template/qemu` |
| Transférer l’image | `scp ubuntu-24.04-server-cloudimg-amd64.img root@192.168.122.32:/var/lib/vz/template/qemu/` |
| Vérifier le transfert | `ls -lh /var/lib/vz/template/qemu/` |
| Vérifier l’image sur Proxmox | `qemu-img info /var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img` |

**Étape suivante :** examiner les stockages Proxmox avec `pvesm status`, puis préparer l’importation du disque dans `local-lvm` pour le déploiement des machines virtuelles par Terraform.