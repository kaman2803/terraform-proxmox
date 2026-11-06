# Section 22 — Génération dynamique des machines virtuelles avec Terraform

## 1. Objectif

Cette section consiste à faire évoluer la ressource Terraform afin de permettre la création dynamique de plusieurs machines virtuelles sur Proxmox VE.

Jusqu'à la section 21, la ressource définissait une seule machine virtuelle avec le nom `srv01`.

L'objectif est désormais de permettre à Terraform de créer automatiquement plusieurs VM à partir de deux variables déjà déclarées dans `variables.tf` :

- `vm_count` : nombre de machines virtuelles à créer.
- `vm_prefix` : préfixe utilisé pour construire les noms des machines.

La génération dynamique doit permettre d'obtenir des noms uniques tels que `srv01`, `srv02`, `srv03`, jusqu'à `srv10`.

## 2. Rappel des variables existantes

Les deux variables utilisées sont déjà déclarées dans `variables.tf`.

### 2.1. Nombre de machines virtuelles

```hcl
variable "vm_count" {
  description = "Nombre de machines virtuelles à déployer"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10 && floor(var.vm_count) == var.vm_count
    error_message = "Le nombre de VM doit être un entier compris entre 1 et 10."
  }
}
```

Cette variable permet de définir le nombre de machines à déployer.

La valeur par défaut est de deux VM, avec une limite comprise entre 1 et 10.

### 2.2. Préfixe des noms

```hcl
variable "vm_prefix" {
  description = "Préfixe des noms des machines virtuelles"
  type        = string
  default     = "srv"
}
```

Cette variable définit le préfixe utilisé dans les noms des machines virtuelles.

Valeur par défaut : `srv`.

## 3. Modification de la ressource Terraform

La ressource existante dans `vm.tf` a été modifiée pour introduire le mécanisme de génération dynamique.

Commande exécutée :

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("vm.tf")
content = path.read_text()

old = '''resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"'''

new = '''resource "proxmox_virtual_environment_vm" "vm" {
  count     = var.vm_count
  name      = format("%s%02d", var.vm_prefix, count.index + 1)
  node_name = "pve1"'''

if old not in content:
    raise SystemExit("Structure attendue introuvable : fichier non modifié.")

path.write_text(content.replace(old, new, 1))
print("Génération dynamique ajoutée.")
PY
```

Résultat obtenu :

```text
Génération dynamique ajoutée.
```

## 4. Analyse du mécanisme de génération dynamique

Les deux lignes ajoutées sont :

```hcl
count = var.vm_count

name = format("%s%02d", var.vm_prefix, count.index + 1)
```

### 4.1. Utilisation de count

```hcl
count = var.vm_count
```

Le paramètre `count` permet de créer plusieurs instances d'une même ressource Terraform.

Il récupère directement le nombre de machines défini dans `vm_count`.

Avec la valeur par défaut de 2, Terraform prépare deux instances de la ressource.

### 4.2. Utilisation de count.index

```hcl
count.index + 1
```

`count.index` représente l'index de chaque instance.

La numérotation commence à zéro :

| Instance | count.index | count.index + 1 |
|---|---:|---:|
| Première VM | 0 | 1 |
| Deuxième VM | 1 | 2 |
| Troisième VM | 2 | 3 |
| Dixième VM | 9 | 10 |

L'ajout de 1 permet de commencer les noms à `01` au lieu de `00`.

### 4.3. Utilisation de format()

```hcl
format("%s%02d", var.vm_prefix, count.index + 1)
```

La fonction `format()` permet de construire le nom de chaque machine.

Les éléments utilisés sont :

- `%s` : insère une chaîne de caractères, ici le préfixe `srv`.
- `%02d` : insère un nombre entier sur deux chiffres, avec un zéro devant si nécessaire.

Exemples :

```text
srv01
srv02
srv03
...
srv10
```

## 5. Contenu complet de vm.tf après modification

Après l'ajout de la génération dynamique, le fichier `vm.tf` contient :

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

Tous les blocs précédemment configurés ont été conservés :

- CPU ;
- mémoire RAM ;
- disque ;
- contrôleur SCSI ;
- carte réseau ;
- Cloud-Init ;
- utilisateur Linux ;
- clé publique SSH ;
- configuration DHCP.

Seule la déclaration du nombre d'instances et la génération des noms ont été modifiées.

## 6. Validation de la configuration Terraform

Après la modification, la commande suivante a été exécutée :

```bash
terraform validate
```

Résultat réellement obtenu :

```text
Success! The configuration is valid.
```

La validation confirme que Terraform accepte la configuration déclarée.

## 7. Vérification des noms avec terraform console

Une vérification interactive a été effectuée pour tester la fonction `format()` et la génération des noms.

Commande exécutée :

```bash
terraform console
```

### 7.1. Test de la première machine

Expression saisie :

```hcl
format("%s%02d", var.vm_prefix, 1)
```

Résultat obtenu :

```text
"srv01"
```

### 7.2. Test de la deuxième machine

Expression saisie :

```hcl
format("%s%02d", var.vm_prefix, 2)
```

Résultat obtenu :

```text
"srv02"
```

### 7.3. Test de la dixième machine

Expression saisie :

```hcl
format("%s%02d", var.vm_prefix, 10)
```

Résultat obtenu :

```text
"srv10"
```

Sortie de la console :

```hcl
exit
```

Les trois tests ont retourné les noms attendus.

## 8. Résultat attendu selon le nombre de VM

Avec les valeurs actuelles :

```hcl
vm_count  = 2
vm_prefix = "srv"
```

Terraform prépare deux instances :

| Instance Terraform | Nom attendu |
|---|---|
| `vm[0]` | `srv01` |
| `vm[1]` | `srv02` |

Si le nombre de machines est porté à 10 :

| Instance Terraform | Nom attendu |
|---|---|
| `vm[0]` | `srv01` |
| `vm[1]` | `srv02` |
| `vm[2]` | `srv03` |
| `vm[3]` | `srv04` |
| `vm[4]` | `srv05` |
| `vm[5]` | `srv06` |
| `vm[6]` | `srv07` |
| `vm[7]` | `srv08` |
| `vm[8]` | `srv09` |
| `vm[9]` | `srv10` |

## 9. Point d'attention sur count

Terraform identifie les instances avec leur index numérique.

Par exemple :

- `proxmox_virtual_environment_vm.vm[0]`
- `proxmox_virtual_environment_vm.vm[1]`

Cette méthode convient à notre scénario de génération de VM numérotées.

Toutefois, une modification ultérieure du nombre d'instances peut entraîner la suppression des instances dont les index deviennent hors limites. Ce comportement devra être pris en compte lors de la gestion du cycle de vie des machines, notamment dans la section 28.

## 10. Conclusion

La ressource Terraform `proxmox_virtual_environment_vm` prend désormais en charge la génération dynamique de plusieurs machines virtuelles.

L'utilisation de `count`, `count.index` et `format()` permet de générer automatiquement des noms uniques à partir des variables `vm_count` et `vm_prefix`.

Les vérifications ont donné les résultats attendus :

- `terraform validate` : réussi.
- Génération de `srv01` : vérifiée.
- Génération de `srv02` : vérifiée.
- Génération de `srv10` : vérifiée.

**Section 22 : terminée et validée.**

**Étape suivante : Section 23 — Premier `terraform plan` et vérification du plan de déploiement.**

Aucune machine virtuelle n'a encore été créée sur Proxmox.