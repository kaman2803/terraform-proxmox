# Section 20 — Configuration matérielle : CPU, RAM, disque et contrôleur

## 1. Objectif

Cette section consiste à définir les ressources matérielles de la future machine virtuelle Ubuntu Server 24.04 LTS sur Proxmox VE.

La configuration est réalisée dans le fichier `vm.tf`, en utilisant les variables déjà déclarées dans `variables.tf`.

Les ressources prévues sont :
- 1 processeur virtuel ;
- 1024 Mio de mémoire RAM ;
- un disque virtuel de 15 Gio ;
- un stockage `local-lvm` ;
- un contrôleur VirtIO SCSI.

## 2. Utilisation des variables Terraform

Les variables suivantes sont déjà présentes dans `variables.tf` :

### 2.1. Nombre de cœurs CPU

```hcl
variable "vm_cores" {
  description = "Nombre de vCPU par machine virtuelle"
  type        = number
  default     = 1
}
```

Cette variable définit le nombre de cœurs virtuels attribués à chaque VM.

### 2.2. Mémoire RAM

```hcl
variable "vm_memory" {
  description = "Mémoire RAM par machine virtuelle en Mio"
  type        = number
  default     = 1024
}
```

La mémoire est exprimée en Mio. La valeur par défaut de 1024 Mio correspond à 1 Gio de RAM.

### 2.3. Taille du disque

```hcl
variable "vm_disk_size" {
  description = "Taille du disque par machine virtuelle en Gio"
  type        = number
  default     = 15
}
```

Cette variable définit une capacité de disque de 15 Gio par machine virtuelle.

## 3. Configuration matérielle dans vm.tf

Le fichier `vm.tf` a été complété avec les blocs `cpu`, `memory`, `scsi_hardware` et `disk`.

### 3.1. Configuration CPU

```hcl
cpu {
  cores = var.vm_cores
}
```

Le paramètre `cores` définit le nombre de cœurs virtuels de la machine.

La valeur est récupérée depuis la variable `vm_cores`, dont la valeur par défaut est `1`.

### 3.2. Configuration mémoire RAM

```hcl
memory {
  dedicated = var.vm_memory
}
```

Le paramètre `dedicated` définit la quantité de mémoire dédiée à la machine virtuelle.

La valeur utilisée est de 1024 Mio, soit 1 Gio.

### 3.3. Choix du contrôleur SCSI

```hcl
scsi_hardware = "virtio-scsi-pci"
```

Ce paramètre définit le contrôleur SCSI utilisé par la machine virtuelle.

Le contrôleur retenu est `virtio-scsi-pci`, qui permet de présenter les disques virtuels à travers le contrôleur VirtIO SCSI.

### 3.4. Déclaration du disque virtuel

```hcl
disk {
  datastore_id = "local-lvm"
  interface    = "scsi0"
  size         = var.vm_disk_size
}
```

Explication des paramètres :

| Paramètre | Fonction | Valeur |
|---|---|---|
| `datastore_id` | Identifie le stockage Proxmox utilisé | `local-lvm` |
| `interface` | Définit l'interface du disque | `scsi0` |
| `size` | Définit la capacité du disque | 15 Gio |

Le stockage `local-lvm` est le stockage LVM-thin identifié et vérifié lors des sections précédentes.

**Point important :** cette déclaration décrit actuellement un disque virtuel vierge. L'image Ubuntu Cloud n'est pas encore importée dans cette configuration. Son intégration sera traitée avant le déploiement effectif.

## 4. Contenu complet de vm.tf après la section 20

À la fin de cette section, le fichier `vm.tf` contient :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
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

La configuration Cloud-Init de la section 19 est conservée.

## 5. Validation Terraform

Après la modification du fichier, la commande suivante a été exécutée :

```bash
terraform validate
```

Résultat réellement obtenu :

```text
Success! The configuration is valid.
```

Cette validation confirme que Terraform accepte la configuration déclarée.

Elle ne signifie pas que le disque a été créé sur Proxmox ou que la VM a déjà été déployée.

## 6. Synthèse de la configuration matérielle

| Composant | Configuration |
|---|---|
| Processeur | 1 vCPU |
| Mémoire RAM | 1024 Mio (1 Gio) |
| Disque système | 15 Gio |
| Stockage | `local-lvm` |
| Interface disque | `scsi0` |
| Contrôleur | `virtio-scsi-pci` |
| Validation Terraform | Réussie |

## 7. Conclusion

La configuration matérielle de la future machine virtuelle a été ajoutée dans le fichier `vm.tf`.

Les paramètres CPU, RAM et disque utilisent les variables existantes de `variables.tf`, ce qui permet de modifier les ressources attribuées sans réécrire la ressource Terraform.

La commande `terraform validate` a confirmé que la configuration est valide.

**Section 20 : terminée et validée.**

**Étape suivante : Section 21 — Configuration réseau : raccordement de la machine virtuelle au bridge Proxmox `vmbr0`.**

Aucune machine virtuelle n'a encore été déployée à cette étape.