# Section 18 — Définition de la ressource Terraform `proxmox_virtual_environment_vm`

## 1. Objectif

Cette section marque le début de la définition des ressources Terraform destinées à créer et gérer les machines virtuelles sur Proxmox VE.

L'objectif est de déclarer une première ressource avec le fournisseur `bpg/proxmox`, déjà installé et configuré dans les sections précédentes.

La ressource utilisée est :

`proxmox_virtual_environment_vm`

Elle permet à Terraform de gérer le cycle de vie des machines virtuelles sur Proxmox.

## 2. Préparation du fichier vm.tf

Dans le répertoire du projet :

`~/lab/terraform-proxmox`

Un nouveau fichier `vm.tf` a été créé pour accueillir la déclaration des machines virtuelles.

Commande exécutée :

```bash
cat > vm.tf <<'EOF'
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"
}
EOF
```

## 3. Analyse de la ressource Terraform

Le contenu du fichier `vm.tf` est le suivant :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"
}
```

Explication des paramètres :

| Paramètre | Description | Valeur |
|---|---|---|
| `resource` | Déclare une ressource gérée par Terraform | — |
| `proxmox_virtual_environment_vm` | Type de ressource fourni par BPG | — |
| `vm` | Nom logique utilisé par Terraform pour identifier la ressource | `vm` |
| `name` | Nom attribué à la machine virtuelle dans Proxmox | `srv01` |
| `var.vm_prefix` | Référence à la variable déclarée dans `variables.tf` | `srv` |
| `node_name` | Nom du nœud Proxmox hébergeant la VM | `pve1` |

### Pourquoi utiliser une variable pour le nom ?

Dans le fichier `variables.tf`, la variable suivante existe déjà :

```hcl
variable "vm_prefix" {
  description = "Préfixe des noms des machines virtuelles"
  type        = string
  default     = "srv"
}
```

L'expression :

```hcl
name = "${var.vm_prefix}01"
```

permet de construire le nom `srv01` à partir du préfixe `srv`.

Cette méthode facilite la personnalisation des noms sans modifier directement la ressource.

## 4. Organisation des fichiers Terraform

À ce stade, le projet dispose notamment des fichiers suivants :

| Fichier | Rôle |
|---|---|
| `versions.tf` | Déclaration de la version Terraform et du fournisseur BPG |
| `provider.tf` | Configuration du fournisseur Proxmox |
| `variables.tf` | Déclaration des paramètres personnalisables |
| `vm.tf` | Déclaration de la ressource de machine virtuelle |

Le fichier `variables.tf` est conservé. Aucune variable existante n'a été supprimée ou redéclarée pendant cette section.

## 5. Validation de la configuration

Après la création de `vm.tf`, la commande suivante a été exécutée :

```bash
terraform validate
```

Résultat réellement obtenu :

```text
Success! The configuration is valid.
```

Cette validation confirme que Terraform accepte la configuration déclarée.

Elle ne signifie pas encore que la machine virtuelle a été créée ou que toutes les opérations de déploiement ont été testées.

## 6. Gestion de plusieurs machines virtuelles

La première déclaration utilise le préfixe `srv` et le suffixe `01`.

La génération dynamique de plusieurs machines sera introduite ultérieurement, conformément à la section 22.

L'objectif sera d'obtenir automatiquement des noms uniques :

| Numéro | Nom prévu |
|---:|---|
| 1 | `srv01` |
| 2 | `srv02` |
| 3 | `srv03` |
| ... | ... |
| 10 | `srv10` |

Cette évolution permettra d'utiliser la variable `vm_count` déjà déclarée dans `variables.tf`.

## 7. État final de la section

| Élément | État |
|---|---|
| Création de `vm.tf` | Réalisée |
| Déclaration de `proxmox_virtual_environment_vm` | Réalisée |
| Définition du nom initial `srv01` | Réalisée |
| Identification du nœud `pve1` | Réalisée |
| Conservation de `variables.tf` | Confirmée |
| Validation Terraform | Réussie |
| Création effective d'une VM | Non réalisée à cette étape |

## 8. Conclusion

La première ressource Terraform destinée à gérer les machines virtuelles Proxmox a été déclarée dans `vm.tf`.

La configuration utilise le fournisseur `bpg/proxmox` et référence les variables déjà définies dans le projet.

La commande `terraform validate` a confirmé que la configuration est valide.

**Section 18 : terminée et validée.**

**Étape suivante : Section 19 — Configuration Cloud-Init : utilisateur Linux `kaman`, injection de la clé publique SSH et configuration IPv4 en DHCP.**