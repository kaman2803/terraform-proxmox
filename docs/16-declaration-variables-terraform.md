# Section 16 — Déclaration des variables Terraform et paramétrage des machines virtuelles

## 16.1. Objectif

Après la configuration du provider Proxmox dans la section 15, nous allons maintenant définir les variables qui permettront de paramétrer les futures machines virtuelles.

L'objectif est de rendre notre infrastructure flexible et évolutive, en évitant de modifier le code Terraform à chaque changement du nombre de machines ou de leurs caractéristiques.

Nous avons retenu une architecture dans laquelle :

- Le nombre de machines virtuelles est paramétrable.
- Les noms des machines sont générés à partir d'un préfixe.
- Les ressources CPU, RAM et disque sont configurables.
- Les valeurs par défaut correspondent à notre besoin initial de deux machines Ubuntu Server 24.04 LTS.

## 16.2. Architecture de paramétrage retenue

Nous prévoyons de déployer des machines virtuelles directement depuis l'image Ubuntu Cloud Image, sans utiliser de template Proxmox ni de machine virtuelle de référence.

Les paramètres retenus par défaut sont les suivants :

| Paramètre | Valeur |
|---|---:|
| Nombre de VM | 2 |
| Préfixe des noms | srv |
| CPU par VM | 1 vCPU |
| RAM par VM | 1024 Mio |
| Disque par VM | 15 Gio |
| Système d'exploitation | Ubuntu Server 24.04 LTS |

Avec cette configuration, les futures machines porteront les noms :

```text
srv01
srv02
```

Le nombre de machines pourra être modifié sans réécrire individuellement leur configuration.

## 16.3. Création du fichier variables.tf

### Objectif

Le fichier `variables.tf` permet de centraliser les paramètres du projet Terraform.

Nous avons choisi de définir cinq variables :

| Variable | Fonction |
|---|---|
| `vm_count` | Nombre de machines virtuelles à déployer |
| `vm_prefix` | Préfixe utilisé pour les noms des VM |
| `vm_cores` | Nombre de vCPU par machine |
| `vm_memory` | Mémoire RAM par machine en Mio |
| `vm_disk_size` | Capacité du disque par machine en Gio |

### Création du fichier

Commande exécutée :

```bash
nano variables.tf
```

### Contenu du fichier

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

variable "vm_prefix" {
  description = "Préfixe des noms des machines virtuelles"
  type        = string
  default     = "srv"
}

variable "vm_cores" {
  description = "Nombre de vCPU par machine virtuelle"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Mémoire RAM par machine virtuelle en Mio"
  type        = number
  default     = 1024
}

variable "vm_disk_size" {
  description = "Taille du disque par machine virtuelle en Gio"
  type        = number
  default     = 15
}
```

### Explication de la configuration

**Variable `vm_count`**

```hcl
variable "vm_count" {
  description = "Nombre de machines virtuelles à déployer"
  type        = number
  default     = 2
}
```

Cette variable détermine le nombre de machines virtuelles à créer.

La valeur par défaut est fixée à deux machines.

**Bloc de validation**

```hcl
validation {
  condition     = var.vm_count >= 1 && var.vm_count <= 10 && floor(var.vm_count) == var.vm_count
  error_message = "Le nombre de VM doit être un entier compris entre 1 et 10."
}
```

Ce bloc impose trois conditions :

1. Le nombre de VM doit être supérieur ou égal à 1.
2. Le nombre de VM ne doit pas dépasser 10.
3. Le nombre doit être entier.

La fonction `floor()` retourne la partie entière inférieure d'un nombre. En comparant son résultat à la valeur initiale, Terraform peut détecter les nombres décimaux.

Par exemple :

- `3` est accepté.
- `11` est rejeté.
- `2.5` est rejeté.

**Variable `vm_prefix`**

```hcl
variable "vm_prefix" {
  description = "Préfixe des noms des machines virtuelles"
  type        = string
  default     = "srv"
}
```

Cette variable définit le préfixe utilisé pour construire les noms des futures VM.

La valeur `srv` permettra de générer des noms tels que `srv01`, `srv02` et `srv03`.

**Variable `vm_cores`**

```hcl
variable "vm_cores" {
  description = "Nombre de vCPU par machine virtuelle"
  type        = number
  default     = 1
}
```

Elle définit le nombre de processeurs virtuels attribués à chaque machine.

**Variable `vm_memory`**

```hcl
variable "vm_memory" {
  description = "Mémoire RAM par machine virtuelle en Mio"
  type        = number
  default     = 1024
}
```

Elle définit la mémoire RAM en Mio.

La valeur `1024` correspond à 1 Gio de mémoire.

**Variable `vm_disk_size`**

```hcl
variable "vm_disk_size" {
  description = "Taille du disque par machine virtuelle en Gio"
  type        = number
  default     = 15
}
```

Elle définit la capacité du disque virtuel de chaque machine en Gio.

## 16.4. Vérification du fichier

Après la création, nous avons affiché le contenu du fichier :

```bash
cat variables.tf
```

Le résultat obtenu correspond au contenu attendu.

Les cinq variables ainsi que la règle de validation sont présentes.

## 16.5. Validation de la configuration Terraform

Nous avons ensuite vérifié que Terraform reconnaissait correctement les variables et leur syntaxe.

### Commande exécutée

```bash
terraform validate
```

### Résultat obtenu

```text
Success! The configuration is valid.
```

### Analyse

La validation a réussi.

Cela confirme que le fichier `variables.tf` est correctement structuré et que Terraform accepte les déclarations effectuées.

## 16.6. Test du nombre de machines virtuelles

Nous avons voulu vérifier que le nombre de machines pouvait être modifié au moment de l'exécution.

### 16.6.1. Test avec trois VM

Commande exécutée :

```bash
terraform plan -var="vm_count=3"
```

Résultat obtenu :

```text
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

La valeur `3` a été acceptée sans erreur.

À ce stade, aucune ressource de machine virtuelle n'a encore été déclarée. Le résultat confirme donc l'acceptation de la variable, mais pas la création effective de trois VM.

### 16.6.2. Test avec onze VM

Nous avons ensuite testé une valeur dépassant la limite définie.

Commande exécutée :

```bash
terraform plan -var="vm_count=11"
```

Résultat obtenu :

```text
Planning failed. Terraform encountered an error while generating this plan.

╷
│ Error: Invalid value for variable
│
│   on variables.tf line 2:
│    2: variable "vm_count" {
│     ├────────────────
│     │ var.vm_count is 11
│
│ Le nombre de VM doit être un entier compris entre 1 et 10.
│
│ This was checked by the validation rule at variables.tf:7,3-13.
╵
```

Terraform a rejeté la valeur `11`.

La règle de validation fonctionne donc correctement.

### 16.6.3. Test avec un nombre décimal

Nous avons également testé une valeur décimale.

Commande exécutée :

```bash
terraform plan -var="vm_count=2.5"
```

Résultat obtenu :

```text
Planning failed. Terraform encountered an error while generating this plan.

╷
│ Error: Invalid value for variable
│
│   on variables.tf line 2:
│    2: variable "vm_count" {
│     ├────────────────
│     │ var.vm_count is 2.5
│
│ Le nombre de VM doit être un entier compris entre 1 et 10.
│
│ This was checked by the validation rule at variables.tf:7,3-13.
╵
```

Terraform a rejeté la valeur `2.5`, conformément à la condition utilisant `floor()`.

## 16.7. Test de personnalisation du préfixe

Nous avons ensuite vérifié qu'il était possible de modifier simultanément le nombre de VM et leur préfixe de nommage.

### Commande exécutée

```bash
terraform plan -var="vm_count=3" -var="vm_prefix=web"
```

Résultat obtenu :

```text
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

Les deux paramètres ont été acceptés sans erreur.

Le préfixe `web` a donc été accepté comme valeur de la variable `vm_prefix`.

La génération effective des noms sera réalisée ultérieurement avec la ressource Proxmox et `for_each`.

## 16.8. Vérification des valeurs par défaut avec terraform console

Afin de vérifier les valeurs définies dans `variables.tf`, nous avons utilisé la console interactive de Terraform.

### Commande exécutée

```bash
terraform console
```

### Vérification des variables

```hcl
var.vm_count
```

Résultat :

```text
2
```

Vérification du préfixe :

```hcl
var.vm_prefix
```

Résultat :

```text
"srv"
```

Vérification du nombre de vCPU :

```hcl
var.vm_cores
```

Résultat :

```text
1
```

Vérification de la mémoire :

```hcl
var.vm_memory
```

Résultat :

```text
1024
```

Vérification de la taille du disque :

```hcl
var.vm_disk_size
```

Résultat :

```text
15
```

Pour quitter la console :

```hcl
exit
```

### Analyse

La console confirme que Terraform charge correctement les cinq valeurs par défaut.

Les paramètres retenus sont donc :

| Variable | Valeur vérifiée |
|---|---:|
| `vm_count` | 2 |
| `vm_prefix` | srv |
| `vm_cores` | 1 |
| `vm_memory` | 1024 |
| `vm_disk_size` | 15 |

## 16.9. Récapitulatif des tests

| Test | Commande ou valeur | Résultat |
|---|---|---|
| Validation de la configuration | `terraform validate` | Réussie |
| Nombre de VM autorisé | `vm_count=3` | Accepté |
| Dépassement de la limite | `vm_count=11` | Rejeté |
| Nombre décimal | `vm_count=2.5` | Rejeté |
| Personnalisation du préfixe | `vm_prefix=web` | Acceptée |
| Lecture des valeurs par défaut | `terraform console` | Réussie |

Ces tests confirment le bon fonctionnement des déclarations de variables et de la règle de validation de `vm_count`.

## 16.10. État du projet après la section 16

La structure du répertoire Terraform est maintenant :

```text
terraform-proxmox/
├── images/
│   └── ubuntu-24.04-server-cloudimg-amd64.img
├── .terraform/
├── .terraform.lock.hcl
├── versions.tf
├── provider.tf
└── variables.tf
```

## Conclusion

La section 16 a permis de rendre le projet Terraform paramétrable et évolutif.

Nous avons créé le fichier `variables.tf` afin de centraliser les caractéristiques des futures machines virtuelles.

Les opérations suivantes ont été réalisées et vérifiées :

1. Déclaration du nombre de machines virtuelles.
2. Mise en place d'une validation limitant le nombre de VM entre 1 et 10.
3. Déclaration du préfixe de nommage.
4. Déclaration des paramètres CPU, RAM et disque.
5. Validation de la configuration Terraform.
6. Test d'une valeur autorisée.
7. Test d'une valeur supérieure à la limite.
8. Test d'une valeur décimale.
9. Test de personnalisation du préfixe.
10. Vérification des valeurs par défaut avec `terraform console`.

La configuration actuelle permet de préparer un déploiement de deux machines par défaut, tout en autorisant une personnalisation du nombre de VM et de leurs caractéristiques.

**Important :** aucune machine virtuelle n'a encore été créée. La génération des noms et la création effective des ressources seront traitées dans les prochaines sections.

### Récapitulatif des commandes essentielles

```bash
nano variables.tf
cat variables.tf
terraform validate
terraform plan -var="vm_count=3"
terraform plan -var="vm_count=11"
terraform plan -var="vm_count=2.5"
terraform plan -var="vm_count=3" -var="vm_prefix=web"
terraform console
```

### Prochaine étape : Section 17

Nous préparerons les paramètres Cloud-Init nécessaires à l'initialisation des machines Ubuntu :

- nom d'hôte ;
- utilisateur système ;
- clé SSH ;
- configuration réseau ;
- paramètres d'initialisation.

Le déploiement restera direct depuis l'image Ubuntu Cloud Image, sans création de template Proxmox.