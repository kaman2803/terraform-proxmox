# Section 28 — Publication du projet Terraform-Proxmox VE sur GitHub

## 1. Objectifs

Cette étape consiste à publier le projet Terraform-Proxmox VE sur GitHub afin de disposer d'un dépôt distant permettant de conserver, versionner et partager les fichiers de configuration Terraform.

Les objectifs sont les suivants :

- Vérifier l'état du dépôt Git local.
- Exclure les images système volumineuses.
- Contrôler l'absence de références sensibles dans les fichiers Terraform.
- Valider la configuration Terraform.
- Préparer les fichiers destinés à la publication.
- Créer le premier commit.
- Créer un dépôt distant GitHub avec GitHub CLI.
- Associer le dépôt local au dépôt distant.
- Publier la branche principale `main`.
- Vérifier la synchronisation entre le dépôt local et GitHub.

## 2. Vérification du dépôt Git local

Les opérations ont été réalisées depuis la machine Kgoumou, dans le répertoire :

```bash
cd ~/lab/terraform-proxmox
```

La commande suivante a permis de vérifier l'état initial du dépôt :

```bash
git status
```

Résultat obtenu :

```text
On branch main

No commits yet

Untracked files:
  (use "git add <file>..." to include in what will be committed)
    .gitignore
    .terraform.lock.hcl
    images/
    provider.tf
    variables.tf
    versions.tf
    vm.tf

nothing added to commit but untracked files present
```

Le dépôt était initialisé sur la branche `main`, mais aucun commit n'avait encore été effectué.

## 3. Exclusion des images système

Le répertoire `images/` contenait les fichiers suivants :

```bash
find images -maxdepth 2 -type f -printf '%p — %s octets\n'
```

Résultat obtenu :

```text
images/ubuntu-24.04-server-cloudimg-amd64.img — 621284352 octets
images/SHA256SUMS — 7843 octets
```

L'image Ubuntu Cloud représente environ 621 Mo.

Comme cette image avait déjà été transférée sur Proxmox et utilisée pour le déploiement des machines virtuelles, il n'était pas nécessaire de la publier dans le dépôt GitHub.

Nous avons donc ajouté la règle suivante dans `.gitignore` :

```gitignore
# Images système et fichiers volumineux
images/
```

Après cette modification, `git status` ne présentait plus le répertoire `images/` parmi les fichiers non suivis.

### 3.1 Vérification des exclusions

Commande exécutée :

```bash
git check-ignore -v .env
git check-ignore -v images/ubuntu-24.04-server-cloudimg-amd64.img
```

Résultat obtenu :

```text
.gitignore:2:.env    .env
.gitignore:12:images/    images/ubuntu-24.04-server-cloudimg-amd64.img
```

Ces résultats confirment que :

- `.env` est exclu du suivi Git.
- Le répertoire `images/` est exclu du suivi Git.

## 4. Contrôle des références sensibles

Avant de publier les fichiers Terraform, nous avons recherché certaines références sensibles dans les fichiers de configuration.

Commande exécutée :

```bash
grep -nE 'PROXMOX_VE_API_TOKEN|password|secret|token' \
provider.tf variables.tf versions.tf vm.tf
```

Aucune ligne n'a été retournée.

Cela signifie qu'aucun des termes recherchés n'a été détecté dans les quatre fichiers examinés.

Le fichier `.env`, qui contient le token API, n'a pas été inclus dans cette recherche et ne doit jamais être publié.

## 5. Validation de la configuration Terraform

Avant de préparer le commit, nous avons vérifié la configuration Terraform.

Commande exécutée :

```bash
terraform validate
```

Résultat obtenu :

```text
Success! The configuration is valid.
```

La configuration Terraform a donc été validée avec succès.

## 6. Préparation des fichiers à publier

Nous avons sélectionné explicitement les fichiers nécessaires au fonctionnement du projet.

Commande exécutée :

```bash
git add .gitignore .terraform.lock.hcl provider.tf variables.tf versions.tf vm.tf
```

Puis nous avons vérifié la sélection :

```bash
git status
```

Résultat obtenu :

```text
On branch main

No commits yet

Changes to be committed:
  (use "git rm --cached <file>..." to unstage)
    new file:   .gitignore
    new file:   .terraform.lock.hcl
    new file:   provider.tf
    new file:   variables.tf
    new file:   versions.tf
    new file:   vm.tf
```

Six fichiers ont été préparés pour le premier commit.

Les fichiers `.env`, les images système, le répertoire `.terraform/` et les fichiers d'état Terraform n'ont pas été sélectionnés.

## 7. Création du premier commit

Après vérification de la sélection, nous avons créé le premier commit.

Commande exécutée :

```bash
git commit -m "Initial commit: Terraform Proxmox VM deployment"
```

Résultat obtenu :

```text
[main (root-commit) 5c67279] Initial commit: Terraform Proxmox VM deployment
 6 files changed, 141 insertions(+)
 create mode 100644 .gitignore
 create mode 100644 .terraform.lock.hcl
 create mode 100644 provider.tf
 create mode 100644 variables.tf
 create mode 100644 versions.tf
 create mode 100644 vm.tf
```

**Informations du commit :**

- Identifiant court : `5c67279`
- Branche : `main`
- Type : `root-commit`
- Fichiers enregistrés : 6
- Insertions : 141

## 8. Vérification de GitHub CLI

Pour créer le dépôt distant directement depuis le terminal, nous avons utilisé GitHub CLI (`gh`).

Commande exécutée :

```bash
gh --version
```

Résultat obtenu :

```text
gh version 2.45.0 (2025-07-18 Ubuntu 2.45.0-1ubuntu0.3)
https://github.com/cli/cli/releases/tag/v2.45.0
```

GitHub CLI était donc déjà installé.

### 8.1 Vérification de l'authentification

Commande exécutée :

```bash
gh auth status
```

Résultat obtenu :

```text
github.com
  ✓ Logged in to github.com account kaman2803 (keyring)
  - Active account: true
  - Git operations protocol: ssh
  - Token: gho_************************************
  - Token scopes: 'admin:public_key', 'gist', 'read:org', 'repo'
```

L'authentification auprès de GitHub était valide avec le compte `kaman2803`.

Le token d'authentification n'est pas reproduit dans cette documentation.

## 9. Création du dépôt distant GitHub

Nous avons créé le dépôt directement depuis le terminal avec GitHub CLI.

Commande exécutée :

```bash
gh repo create terraform-proxmox \
  --public \
  --description "Infrastructure as Code: automated deployment of Ubuntu Server VMs on Proxmox VE using Terraform and Cloud-Init."
```

Résultat obtenu :

```text
✓ Created repository kaman2803/terraform-proxmox on GitHub
https://github.com/kaman2803/terraform-proxmox
```

Le dépôt distant a été créé avec les caractéristiques suivantes :

| Paramètre | Valeur |
|---|---|
| Propriétaire | `kaman2803` |
| Nom | `terraform-proxmox` |
| Visibilité | Public |
| Branche locale | `main` |
| Initialisation README | Non |
| Initialisation .gitignore | Non |

Le dépôt distant a été créé sans README ni `.gitignore`, car ces fichiers étaient déjà gérés localement ou devaient être ajoutés ultérieurement.

## 10. Association du dépôt local au dépôt distant

Nous avons ensuite configuré le dépôt distant sous le nom `origin`.

Commande exécutée :

```bash
git remote add origin git@github.com:kaman2803/terraform-proxmox.git
```

Vérification :

```bash
git remote -v
```

Résultat obtenu :

```text
origin  git@github.com:kaman2803/terraform-proxmox.git (fetch)
origin  git@github.com:kaman2803/terraform-proxmox.git (push)
```

Le dépôt local est maintenant associé au dépôt GitHub via SSH.

## 11. Publication de la branche main

La publication du premier commit a été réalisée avec la commande :

```bash
git push -u origin main
```

Résultat obtenu :

```text
Enumerating objects: 8, done.
Counting objects: 100% (8/8), done.
Delta compression using up to 4 threads
Compressing objects: 100% (7/7), done.
Writing objects: 100% (8/8), 2.33 KiB | 2.33 MiB/s, done.
Total 8 (delta 0), reused 0 (delta 0), pack-reused 0
To github.com:kaman2803/terraform-proxmox.git
 * [new branch]      main -> main
branch 'main' set up to track 'origin/main'.
```

La branche locale `main` a été publiée avec succès sur GitHub.

L'option `-u` permet également de configurer `origin/main` comme branche distante de suivi.

## 12. Vérification finale de la synchronisation

Après la publication, nous avons vérifié l'état du dépôt local.

Commande exécutée :

```bash
git status
```

Résultat obtenu :

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

Le dépôt local est propre et synchronisé avec le dépôt distant.

Nous avons également vérifié le dernier commit :

```bash
git log -1 --oneline
```

Résultat obtenu :

```text
5c67279 (HEAD -> main, origin/main) Initial commit: Terraform Proxmox VM deployment
```

Cette sortie confirme que le même commit est présent sur la branche locale `main` et sur la branche distante `origin/main`.

## 13. Accès au dépôt GitHub

Le dépôt officiel du projet est accessible à l'adresse suivante :

**https://github.com/kaman2803/terraform-proxmox**

Le dépôt contient actuellement les six fichiers de configuration publiés lors du premier commit.

La documentation technique composée des sections 01 à 27 et le README principal seront ajoutés lors d'une prochaine publication.

## 14. Bilan de la section

| Opération | Résultat |
|---|---|
| Vérification du dépôt local | Validée |
| Exclusion de `.env` | Validée |
| Exclusion des images système | Validée |
| Contrôle des références sensibles recherchées | Validé |
| Validation Terraform | Réussie |
| Sélection des fichiers à publier | Validée |
| Premier commit | Créé |
| Installation et vérification de GitHub CLI | Validées |
| Authentification GitHub | Validée |
| Création du dépôt distant | Réussie |
| Association du dépôt local à `origin` | Réussie |
| Publication de la branche `main` | Réussie |
| Synchronisation Git | Confirmée |

## 15. Conclusion

Cette section a permis de publier une première version du projet Terraform-Proxmox VE sur GitHub.

Le dépôt distant a été créé directement depuis Kgoumou avec GitHub CLI. Les fichiers de configuration Terraform ont été versionnés et publiés sur la branche `main`, après exclusion des secrets locaux et de l'image système Ubuntu Cloud.

La vérification finale confirme que le dépôt local est synchronisé avec GitHub et ne contient aucune modification en attente.

**La section 28 est terminée.**

La prochaine étape consistera à préparer le README principal du projet et à intégrer les 27 sections de documentation technique afin de rendre le dépôt plus lisible et exploitable par d'autres administrateurs systèmes et réseaux.