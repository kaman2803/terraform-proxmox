# Section 19 — Configuration Cloud-Init : utilisateur, clé SSH et DHCP

## 1. Objectif

Cette section consiste à intégrer les paramètres Cloud-Init dans la ressource Terraform `proxmox_virtual_environment_vm`.

Cloud-Init permet de préparer automatiquement la configuration initiale du système Ubuntu lors du déploiement d'une machine virtuelle.

Les paramètres configurés sont :

- La création de l'utilisateur Linux `kaman`.
- L'injection de la clé publique SSH existante.
- La configuration automatique de l'adressage IPv4 par DHCP.

La configuration est réalisée dans le fichier `vm.tf`, sans modifier le fichier `variables.tf`.

## 2. Utilisation des variables existantes

Les paramètres nécessaires avaient déjà été déclarés dans `variables.tf`.

### 2.1. Variable de l'utilisateur Linux

```hcl
variable "vm_username" {
  description = "Utilisateur Linux créé par Cloud-Init"
  type        = string
  default     = "kaman"
}
```

Cette variable définit le nom du compte Linux qui sera configuré par Cloud-Init.

### 2.2. Variable du chemin de la clé publique SSH

```hcl
variable "ssh_public_key_path" {
  description = "Chemin de la clé publique SSH utilisée par Cloud-Init"
  type        = string
  default     = "/home/kaman-goumou/.ssh/id_ed25519.pub"
}
```

Elle indique à Terraform où trouver la clé publique SSH sur la machine `Kgoumou`.

La clé privée reste sur la machine hôte et n'est pas injectée dans la VM.

## 3. Intégration de Cloud-Init dans vm.tf

Le fichier `vm.tf`, créé à la section 18, a été complété avec un bloc `initialization`.

Commande exécutée :

```bash
cat > vm.tf <<'EOF'
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"

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
EOF
```

## 4. Analyse de la configuration

Le contenu final de `vm.tf` obtenu après exécution :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"

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

### 4.1. Bloc initialization

```hcl
initialization {
  ...
}
```

Ce bloc regroupe les paramètres d'initialisation Cloud-Init de la machine virtuelle.

### 4.2. Création du compte Linux

```hcl
user_account {
  username = var.vm_username
}
```

Le paramètre `username` récupère la valeur de la variable `vm_username`.

Valeur utilisée : `kaman`.

### 4.3. Injection de la clé publique SSH

```hcl
keys = [trimspace(file(var.ssh_public_key_path))]
```

Cette expression utilise deux fonctions Terraform :

- `file()` : lit le contenu du fichier de clé publique SSH.
- `trimspace()` : supprime les espaces et caractères de fin de ligne inutiles.

La clé est placée dans une liste, conformément au format attendu par le paramètre `keys`.

Cela permet de préparer l'authentification SSH par clé publique pour le compte Linux configuré.

### 4.4. Configuration réseau DHCP

```hcl
ip_config {
  ipv4 {
    address = "dhcp"
  }
}
```

Cette configuration demande à Cloud-Init de configurer automatiquement l'adresse IPv4 de la machine virtuelle par DHCP.

Le réseau retenu lors de la section 17 est celui raccordé au bridge Proxmox `vmbr0`.

## 5. Validation de la configuration

Après la modification de `vm.tf`, la commande suivante a été exécutée :

```bash
terraform validate
```

Résultat réellement obtenu :

```text
Success! The configuration is valid.
```

Cette validation confirme que Terraform accepte la configuration déclarée.

## 6. Synthèse des paramètres Cloud-Init

| Paramètre | Valeur |
|---|---|
| Bloc d'initialisation | `initialization` |
| Compte Linux | `kaman` |
| Variable utilisateur | `var.vm_username` |
| Clé publique SSH | `id_ed25519.pub` |
| Lecture de la clé | `file()` |
| Nettoyage de la chaîne | `trimspace()` |
| Configuration IPv4 | DHCP |
| Validation Terraform | Réussie |

## 7. Conclusion

La configuration Cloud-Init a été intégrée avec succès dans la ressource Terraform `proxmox_virtual_environment_vm`.

Les paramètres permettent de préparer l'utilisateur Linux `kaman`, l'accès SSH par clé publique et l'adressage IPv4 automatique par DHCP.

La commande `terraform validate` a confirmé que la configuration est valide.

**Section 19 : terminée et validée.**

**Étape suivante : Section 20 — Configuration matérielle : CPU, RAM, disque et contrôleur.**

À ce stade, aucune machine virtuelle n'a encore été déployée sur Proxmox.