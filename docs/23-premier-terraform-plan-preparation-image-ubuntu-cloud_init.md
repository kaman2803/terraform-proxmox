# Section 23 – Premier Terraform Plan et préparation de l'import de l'image Ubuntu Cloud-Init

## 1. Objectif

Cette section consiste à préparer le premier plan de déploiement Terraform des machines virtuelles Ubuntu Server sur Proxmox VE.

L'objectif est de vérifier que Terraform peut :

- reconnaître l'image Ubuntu Cloud-Init présente sur Proxmox ;
- importer cette image depuis le stockage `local` vers `local-lvm` ;
- préparer la création des deux machines virtuelles `srv01` et `srv02` ;
- prendre en compte les paramètres matériels, réseau et Cloud-Init précédemment définis.

Aucun déploiement de VM n'est effectué dans cette section.

## 2. Préparation de l'image Cloud-Init sur PVE1

L'image Ubuntu Server 24.04 Cloud-Init avait déjà été téléchargée sur Kgoumou, puis transférée sur le nœud Proxmox `pve1`.

Cette image est destinée à servir de disque source pour les machines virtuelles créées par Terraform.

### 2.1. Vérification de la configuration du stockage

Nous avons commencé par examiner la configuration des stockages Proxmox.

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

Cette configuration présente deux stockages :

- `local` : stockage de type répertoire situé dans `/var/lib/vz`. Il accepte notamment le contenu `import`.
- `local-lvm` : stockage LVM-thin destiné aux disques des machines virtuelles et des conteneurs.

Le contenu `import` étant déjà autorisé sur `local`, aucune modification de la configuration n'a été nécessaire.

### 2.2. Création du répertoire et copie de l'image

Nous avons créé le répertoire destiné aux images importables, puis copié l'image Ubuntu déjà présente dans le répertoire des images QEMU.

**Commande exécutée :**

```bash
mkdir -p /var/lib/vz/import && cp -av /var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img /var/lib/vz/import/
```

**Résultat obtenu :**

```text
'/var/lib/vz/template/qemu/ubuntu-24.04-server-cloudimg-amd64.img' -> '/var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img'
```

La copie du fichier s'est effectuée correctement.

### 2.3. Première vérification des volumes importables

Nous avons ensuite demandé à Proxmox d'afficher les volumes de type `import`.

**Commande exécutée :**

```bash
pvesm list local --content import
```

**Résultat obtenu :**

```text
Volid Format  Type      Size VMID
```

Aucun volume n'était reconnu à ce stade.

### 2.4. Première tentative de résolution du chemin

Nous avons tenté de résoudre le chemin du volume avec son extension initiale `.img`.

**Commande exécutée :**

```bash
pvesm path local:import/ubuntu-24.04-server-cloudimg-amd64.img
```

**Résultat obtenu :**

```text
unable to parse directory volume name 'import/ubuntu-24.04-server-cloudimg-amd64.img'
```

Cette commande a échoué : Proxmox ne reconnaissait pas ce nom comme un volume importable.

### 2.5. Vérification des volumes du stockage local

Une seconde vérification générale a confirmé l'absence de volume enregistré.

**Commande exécutée :**

```bash
pvesm list local
```

**Résultat obtenu :**

```text
Volid Format  Type      Size VMID
```

### 2.6. Vérification de la présence du fichier

Afin de vérifier que la copie était bien présente sur le serveur, nous avons utilisé `ls`.

**Commande exécutée :**

```bash
ls -lh /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img
```

**Résultat obtenu :**

```text
-rw-r--r-- 1 root root 593M Nov  6 02:32 /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img
```

Le fichier était bien présent dans le répertoire `/var/lib/vz/import/`, avec une taille de 593 Mio.

### 2.7. Nouvelle vérification de la configuration du stockage

Nous avons relu la configuration pour confirmer que le contenu `import` était toujours activé.

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

La configuration du stockage était donc correcte. Le problème ne provenait pas de l'absence du type de contenu `import`.

### 2.8. Identification du format réel de l'image

Nous avons utilisé `qemu-img info` pour identifier le format réel du fichier et vérifier son intégrité.

**Commande exécutée :**

```bash
qemu-img info /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img
```

**Résultat obtenu :**

```text
image: /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img
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
    filename: /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img
    protocol type: file
    file length: 593 MiB (621284352 bytes)
    disk size: 593 MiB
```

L'analyse confirme les caractéristiques suivantes :

| Paramètre | Valeur |
|---|---|
| Format réel | QCOW2 |
| Taille virtuelle | 3,5 Gio |
| Taille physique | 593 Mio |
| Compatibilité | 1.1 |
| État de corruption | `false` |

L'image était donc valide et exploitable. Son extension initiale `.img` ne permettait cependant pas à Proxmox de reconnaître correctement le volume dans notre répertoire d'import.

### 2.9. Renommage de l'image

Nous avons donc renommé le fichier en conservant intégralement son contenu.

**Commande exécutée :**

```bash
mv /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.img /var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.qcow2
```

**Résultat obtenu :**

Aucun message d'erreur n'a été retourné.

### 2.10. Vérification de la reconnaissance du volume

Après le renommage, nous avons relancé l'inventaire du stockage `local`.

**Commande exécutée :**

```bash
pvesm list local
```

**Résultat obtenu :**

```text
Volid                                                 Format  Type           Size VMID
local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2 qcow2   import    621284352
```

Cette fois, Proxmox reconnaît correctement l'image comme un volume de type `import`.

L'identifiant du volume est désormais :

```text
local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2
```

### 2.11. Vérification du chemin physique du volume

Pour terminer, nous avons vérifié le chemin physique associé à cet identifiant.

**Commande exécutée :**

```bash
pvesm path local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2
```

**Résultat obtenu :**

```text
/var/lib/vz/import/ubuntu-24.04-server-cloudimg-amd64.qcow2
```

Le chemin physique est correctement résolu par Proxmox.

**Bilan :** l'image Ubuntu Cloud-Init est maintenant reconnue comme volume importable par Proxmox VE. Aucun nouveau téléchargement ni aucune conversion de l'image n'ont été nécessaires.

## 3. Intégration de l'image dans Terraform sur Kgoumou

Après avoir finalisé la préparation du stockage sur PVE1, nous sommes revenus sur Kgoumou, dans le répertoire du projet Terraform.

```bash
cd /home/kaman-goumou/lab/terraform-proxmox
```

### 3.1. Modification de la ressource VM

Nous avons adapté le bloc `disk` dans `vm.tf` pour importer l'image Ubuntu existante vers le stockage `local-lvm`.

**Configuration intégrée :**

```hcl
disk {
  datastore_id = "local-lvm"
  interface    = "scsi0"
  size         = var.vm_disk_size

  import_from = "local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2"
}
```

L'attribut `import_from` désigne le volume source enregistré sur Proxmox.

Le paramètre `datastore_id = "local-lvm"` indique le stockage de destination du disque de la machine virtuelle.

### 3.2. Vérification du fichier vm.tf

**Commande exécutée :**

```bash
cat vm.tf
```

**Résultat obtenu :**

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  count     = var.vm_count
  name      = format("%s%02d", var.vm_prefix, count.index + 1)
  node_name = "pve1"

  cpu {
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_memory
  }

  scsi_hardware = "virtio-scsi-pci"

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.vm_disk_size

      import_from = "local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2"
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  initialization {
    user_account {
      username = var.vm_username
      keys     = [trimspace(file(var.ssh_public_key_path))]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
```

Le bloc `import_from` est bien présent dans la ressource. Son indentation était décalée dans cette première sortie, sans empêcher la validation de la configuration.

### 3.3. Validation de la configuration Terraform

Avant de lancer le plan, nous avons vérifié la syntaxe et la cohérence de la configuration.

**Commande exécutée :**

```bash
terraform validate
```

**Résultat obtenu :**

```text
Success! The configuration is valid.
```

La validation Terraform a réussi.

## 4. Première tentative de Terraform Plan

Après la validation, nous avons lancé la première simulation de déploiement.

**Commande exécutée :**

```bash
terraform plan
```

**Résultat obtenu :**

```text
Planning failed. Terraform encountered an error while generating this plan.

╷
│ Error: Missing Proxmox VE API Endpoint
│
│   with provider["registry.terraform.io/bpg/proxmox"],
│   on provider.tf line 1, in provider "proxmox":
│    1: provider "proxmox" {}
│
│ The provider cannot create the Proxmox VE API client as there is a missing or empty value for the API endpoint. Set the host
│ value in the configuration or use the PROXMOX_VE_ENDPOINT environment variable. If either is already set, ensure the value
│ is not empty.
╵
```

### 4.1. Analyse de l'erreur

Le provider `bpg/proxmox` ne parvient pas à initialiser le client API, car l'adresse de l'API Proxmox n'est pas disponible dans l'environnement du terminal.

Le fichier `provider.tf` utilise volontairement une configuration minimale :

```hcl
provider "proxmox" {}
```

L'adresse du serveur doit donc être fournie par la variable d'environnement :

```text
PROXMOX_VE_ENDPOINT
```

### 4.2. Vérification de la variable d'environnement

Nous avons vérifié si cette variable était toujours définie dans le terminal de Kgoumou.

**Commande exécutée :**

```bash
echo "$PROXMOX_VE_ENDPOINT"
```

**Résultat obtenu :**

```text

```

La sortie vide confirme que la variable n'était pas définie dans ce terminal au moment de l'exécution de `terraform plan`.

L'erreur est donc liée à l'initialisation de la connexion API et non à l'image Cloud-Init ou à la syntaxe du fichier `vm.tf`.

## 5. État d'avancement de la section

| Élément | État |
|---|---|
| Image Ubuntu téléchargée sur Kgoumou | Validé |
| Image transférée sur PVE1 | Validé |
| Stockage `local` configuré avec `import` | Validé |
| Répertoire `/var/lib/vz/import` créé | Validé |
| Image copiée dans le répertoire d'import | Validé |
| Format QCOW2 vérifié | Validé |
| Image renommée en `.qcow2` | Validé |
| Volume reconnu par `pvesm list` | Validé |
| Chemin résolu par `pvesm path` | Validé |
| `import_from` intégré dans `vm.tf` | Validé |
| `terraform validate` | Réussi |
| Premier `terraform plan` | Échec : endpoint API absent |
| Création des VM | Non effectuée |

## 6. Prochaine opération

La prochaine étape consiste à rétablir la variable d'environnement de l'API Proxmox sur Kgoumou.

**Commande à exécuter :**

```bash
export PROXMOX_VE_ENDPOINT="https://192.168.122.32:8006/"
```

Puis vérifier sa valeur :

```bash
echo "$PROXMOX_VE_ENDPOINT"
```

Après cette vérification, nous contrôlerons la disponibilité du token API sans afficher sa valeur, puis nous relancerons :

```bash
terraform plan
```

Le plan sera examiné avant toute application.

**Statut de la section 23 : EN COURS – Image Cloud-Init correctement enregistrée et configuration Terraform validée. Connexion API à rétablir avant le premier plan réussi.**