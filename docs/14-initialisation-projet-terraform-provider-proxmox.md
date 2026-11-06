# Section 14 — Initialisation du projet Terraform et gestion du provider Proxmox

## 14.1. Objectif

Après avoir préparé et transféré l'image Ubuntu Server 24.04 Cloud Image sur Proxmox, nous commençons la configuration du projet Terraform.

Cette section consiste à préparer l'environnement Terraform et à installer le provider nécessaire pour communiquer avec l'API de Proxmox VE.

L'architecture retenue reste la suivante :

- Déploiement direct des machines virtuelles depuis l'image Ubuntu Cloud Image.
- Configuration initiale des VM avec Cloud-Init.
- Aucun template Proxmox préexistant.
- Aucune machine virtuelle de référence.
- Deux machines virtuelles à déployer : `srv01` et `srv02`.
- Stockage des disques virtuels sur `local-lvm`.

## 14.2. Présentation de l'environnement de travail

Le projet Terraform est hébergé sur la machine Ubuntu `Kgoumou`.

Répertoire de travail :

```text
/home/kaman-goumou/lab/terraform-proxmox
```

Accès au répertoire :

```bash
cd ~/lab/terraform-proxmox
```

La version de Terraform précédemment installée et vérifiée est :

```text
Terraform v1.17.1
on linux_amd64
```

## 14.3. Création du fichier versions.tf

### Objectif

Le fichier `versions.tf` permet de déclarer les exigences de version du projet Terraform ainsi que les providers nécessaires à son fonctionnement.

Dans notre cas, nous utilisons le provider `bpg/proxmox`, qui permet à Terraform d'interagir avec les ressources de Proxmox VE.

### Création du fichier

Commande exécutée :

```bash
nano versions.tf
```

Contenu du fichier :

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.120.0"
    }
  }
}
```

### Explication de la configuration

**Bloc `terraform`**

Il définit les exigences générales du projet Terraform.

**Directive `required_version`**

```hcl
required_version = ">= 1.5.0"
```

Elle indique que le projet nécessite Terraform en version 1.5.0 ou supérieure.

Notre environnement utilise Terraform 1.17.1, ce qui satisfait cette condition.

**Bloc `required_providers`**

Il déclare les providers externes dont le projet a besoin.

**Directive `source`**

```hcl
source = "bpg/proxmox"
```

Elle identifie le provider Proxmox publié sous l'espace de noms `bpg`.

**Directive `version`**

```hcl
version = "~> 0.120.0"
```

Elle définit la contrainte de version du provider. Elle autorise les versions correctives de la série 0.120.x, sans autoriser automatiquement le passage à la série 0.121.x.

### Vérification du fichier

Commande exécutée :

```bash
cat versions.tf
```

Résultat obtenu :

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.120.0"
    }
  }
}
```

Le contenu affiché correspond à la configuration attendue.

## 14.4. Initialisation du projet avec terraform init

### Objectif

La commande `terraform init` permet d'initialiser le répertoire de travail Terraform.

Elle prépare l'environnement nécessaire à l'exécution des futures commandes Terraform, notamment en téléchargeant les providers déclarés dans la configuration.

### Commande exécutée

```bash
terraform init
```

### Résultat obtenu

```text
Initializing the backend...

Initializing provider plugins...
- Finding bpg/proxmox versions matching "~> 0.120.0"...
- Installing bpg/proxmox v0.120.0...
- Installed bpg/proxmox v0.120.0 (self-signed, key ID 0B3405B36193A495)
Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://developer.hashicorp.com/terraform/cli/plugins/signing

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration in Terraform,
rerun "terraform init" to reinitialize your working directory. If you forget,
other commands will detect it and remind you to do so if necessary.
```

### Analyse du résultat

L'initialisation s'est terminée avec succès.

Les opérations suivantes ont été réalisées :

1. Initialisation du backend Terraform.
2. Recherche du provider `bpg/proxmox` correspondant à la contrainte `~> 0.120.0`.
3. Téléchargement du provider `bpg/proxmox` version `0.120.0`.
4. Installation du provider dans l'environnement Terraform.
5. Création du fichier de verrouillage des dépendances `.terraform.lock.hcl`.

La mention `self-signed` dans le résultat concerne la signature du provider et son mode de signature. Elle ne signifie pas que le certificat TLS du serveur Proxmox est invalide.

## 14.5. Comprendre le fichier .terraform.lock.hcl

Après l'installation du provider, Terraform a automatiquement créé le fichier :

```text
.terraform.lock.hcl
```

Ce fichier conserve les informations relatives aux versions sélectionnées des providers ainsi que leurs sommes de contrôle.

Son intérêt est de garantir que les prochaines initialisations utilisent la même version du provider, sauf modification volontaire de la sélection.

Il est recommandé de conserver ce fichier dans le dépôt Git du projet afin de garantir la cohérence de l'environnement entre plusieurs machines.

Le fichier est géré automatiquement par Terraform : il ne doit pas être modifié manuellement.

## 14.6. Vérification des fichiers et répertoires créés

Après l'initialisation, nous vérifions le contenu du répertoire du projet.

Commande exécutée :

```bash
ls -la
```

Résultat obtenu :

```text
total 24
drwxrwxr-x   4 kaman-goumou kaman-goumou 4096 Nov  6 02:45 .
drwxrwxr-x+ 10 kaman-goumou kaman-goumou 4096 Nov  6 02:22 ..
drwxrwxr-x   2 kaman-goumou kaman-goumou 4096 Nov  6 02:27 images
drwxr-xr-x   3 kaman-goumou kaman-goumou 4096 Nov  6 02:45 .terraform
-rw-r--r--   1 kaman-goumou kaman-goumou 1334 Nov  6 02:45 .terraform.lock.hcl
-rw-rw-r--   1 kaman-goumou kaman-goumou  155 Nov  6 02:45 versions.tf
```

### Analyse

| Élément | Rôle | État |
|---|---|---|
| `images/` | Contient l'image Ubuntu Cloud Image téléchargée sur Kgoumou. | Présent |
| `.terraform/` | Contient les éléments installés et gérés par Terraform, notamment les providers. | Présent |
| `.terraform.lock.hcl` | Verrouille les versions et les sommes de contrôle des providers. | Présent |
| `versions.tf` | Déclare les exigences de version et le provider Proxmox. | Présent |

La vérification confirme que les fichiers et répertoires attendus sont présents.

## Conclusion

La première partie de la configuration Terraform est terminée.

Les opérations réalisées et validées sont :

1. Création du fichier `versions.tf`.
2. Déclaration de la version minimale de Terraform.
3. Déclaration du provider `bpg/proxmox`.
4. Fixation de la contrainte de version `~> 0.120.0`.
5. Initialisation du projet avec `terraform init`.
6. Installation effective du provider `bpg/proxmox` version `0.120.0`.
7. Création du fichier `.terraform.lock.hcl`.
8. Vérification des fichiers et répertoires générés.

### Récapitulatif des commandes essentielles

| Opération | Commande |
|---|---|
| Accéder au projet | `cd ~/lab/terraform-proxmox` |
| Créer le fichier | `nano versions.tf` |
| Afficher sa configuration | `cat versions.tf` |
| Initialiser Terraform | `terraform init` |
| Vérifier les fichiers | `ls -la` |

### État du projet à la fin de cette étape

```text
terraform-proxmox/
├── images/
│   └── ubuntu-24.04-server-cloudimg-amd64.img
├── .terraform/
├── .terraform.lock.hcl
└── versions.tf
```

### Prochaine étape

La suite consistera à créer le fichier `provider.tf`.

Ce fichier permettra de configurer la connexion entre Terraform et l'API de Proxmox VE, en utilisant le token API précédemment créé et la configuration TLS préparée.

La configuration du provider sera étudiée progressivement, en expliquant chaque paramètre et en évitant d'exposer le secret du token dans le fichier.