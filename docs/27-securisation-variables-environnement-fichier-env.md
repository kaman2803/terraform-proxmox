# Section 27 — Sécurisation des variables d'environnement et initialisation de Git

## 1. Objectifs

Cette étape consiste à sécuriser les informations d'authentification utilisées par Terraform pour communiquer avec l'API de Proxmox VE.

Les objectifs sont les suivants :

- Centraliser les variables d'environnement dans un fichier `.env`.
- Protéger le fichier contenant le token API.
- Charger les variables dans le terminal sans exposer le secret.
- Exclure les informations sensibles et les fichiers d'état Terraform du suivi Git.
- Initialiser un dépôt Git local sur la branche `main`.
- Vérifier que Terraform communique toujours correctement avec Proxmox.

**Environnement de travail :**

- Système : Ubuntu 24.04 LTS
- Répertoire : `~/lab/terraform-proxmox`
- Hyperviseur : Proxmox VE 9.2.25
- Outil IaC : Terraform v1.17.1
- Provider : `bpg/proxmox` v0.120.0

## 2. Création du fichier .env

Jusqu'à présent, les variables nécessaires à l'authentification auprès de Proxmox étaient chargées manuellement dans le terminal.

Pour éviter de devoir saisir ces informations à chaque nouvelle session, nous avons créé un fichier `.env`.

Depuis le répertoire du projet :

```bash
cd ~/lab/terraform-proxmox
```

Vérification préalable de l'existence du fichier :

```bash
if [ -f .env ]; then
    echo ".env existe déjà"
else
    echo ".env absent"
fi
```

Le fichier `.env` était absent.

### 2.1 Création et protection du fichier

La commande suivante permet de saisir le secret de manière masquée, de construire les variables d'environnement et de les enregistrer dans `.env`.

```bash
read -rsp "Secret API Token Proxmox : " PVE_TOKEN_SECRET
echo

TOKEN_ID='terraform@pve!terraform-provider'

{
  printf 'export PROXMOX_VE_ENDPOINT=%q\n' 'https://192.168.122.32:8006/'
  printf 'export PROXMOX_VE_API_TOKEN=%q\n' "${TOKEN_ID}=${PVE_TOKEN_SECRET}"
} > .env

unset PVE_TOKEN_SECRET TOKEN_ID

chmod 600 .env
```

**Explications :**

- `read -rsp` : demande le secret sans afficher les caractères saisis.
- `TOKEN_ID` : identifiant du token API Proxmox.
- `printf %q` : écrit les valeurs dans un format compatible avec le shell.
- `unset` : supprime les variables temporaires contenant le secret.
- `chmod 600` : limite la lecture et l'écriture au propriétaire du fichier.

Le fichier contient deux instructions `export` :

```bash
export PROXMOX_VE_ENDPOINT=...
export PROXMOX_VE_API_TOKEN=...
```

Le contenu réel du token n'est volontairement pas reproduit dans cette documentation.

### 2.2 Vérification des permissions

Commande exécutée :

```bash
stat -c '%A %a %n' .env
```

Résultat obtenu :

```text
-rw------- 600 .env
```

**Interprétation :**

| Permission | Signification |
|---|---|
| `rw-` | Le propriétaire peut lire et modifier le fichier. |
| `---` | Les membres du groupe ne disposent d'aucun accès. |
| `---` | Les autres utilisateurs ne disposent d'aucun accès. |

Le fichier est donc protégé par les permissions `600`.

## 3. Chargement des variables d'environnement

Pour charger les variables dans le terminal courant, la commande suivante a été exécutée :

```bash
source .env
```

Vérification de leur présence sans afficher les valeurs sensibles :

```bash
if [ -n "$PROXMOX_VE_ENDPOINT" ] && [ -n "$PROXMOX_VE_API_TOKEN" ]; then
    echo "Variables API chargées depuis .env"
else
    echo "Erreur de chargement"
fi
```

Résultat obtenu :

```text
Variables API chargées depuis .env
```

Les deux variables sont donc disponibles dans la session actuelle.

**Remarque :** dans un nouveau terminal, il faudra recharger les variables avec :

```bash
cd ~/lab/terraform-proxmox
source .env
```

## 4. Création du fichier .gitignore

Avant d'initialiser Git, nous avons créé un fichier `.gitignore` afin d'exclure les fichiers sensibles et les fichiers générés par Terraform.

Commande exécutée :

```bash
cat > .gitignore <<'EOF'
# Secrets locaux
.env

# Fichiers Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
crash.log
EOF
```

Vérification du contenu :

```bash
cat .gitignore
```

Résultat obtenu :

```text
# Secrets locaux
.env

# Fichiers Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
crash.log
```

**Rôle des exclusions :**

| Règle | Rôle |
|---|---|
| `.env` | Exclure les variables sensibles et le token API. |
| `.terraform/` | Exclure les fichiers internes du provider et les modules téléchargés. |
| `*.tfstate` | Exclure les fichiers d'état Terraform. |
| `*.tfstate.*` | Exclure les fichiers d'état secondaires et sauvegardes. |
| `*.tfplan` | Exclure les plans Terraform enregistrés. |
| `tfplan` | Exclure le plan enregistré utilisé précédemment. |
| `crash.log` | Exclure les journaux d'incident Terraform. |

## 5. Initialisation du dépôt Git

Nous avons ensuite vérifié si Git reconnaissait la règle d'exclusion `.env` :

```bash
git check-ignore -v .env
```

Première tentative : cette commande a retourné :

```text
fatal: not a git repository (or any of the parent directories): .git
```

Cette erreur était normale : le dépôt Git n'avait pas encore été initialisé.

### 5.1 Initialisation

Commande exécutée :

```bash
git init
```

Résultat obtenu :

```text
hint: Using 'master' as the name for the initial branch. This default branch name
hint: is subject to change. To configure the initial branch name to use in all
hint: of your new repositories, which will suppress this warning, call:
hint:
hint:     git config --global init.defaultBranch <name>
hint:
hint: Names commonly chosen instead of 'master' are 'main', 'trunk' and
hint: 'development'. The just-created branch can be renamed via this command:
hint:
hint:     git branch -m <name>
Initialized empty Git repository in /home/kaman-goumou/lab/terraform-proxmox/.git/
```

Git a créé le répertoire caché `.git/` et initialisé un dépôt local.

### 5.2 Vérification de l'exclusion de .env

Après l'initialisation, la commande a été exécutée à nouveau :

```bash
git check-ignore -v .env
```

Résultat obtenu :

```text
.gitignore:2:.env    .env
```

Cette sortie confirme que Git applique bien la règle `.env` présente à la deuxième ligne du fichier `.gitignore`.

### 5.3 Renommage de la branche principale

À l'initialisation, Git avait créé la branche `master`.

Nous avons choisi d'utiliser `main`.

Commande exécutée :

```bash
git branch -m main
```

Vérification :

```bash
git branch --show-current
```

Résultat obtenu :

```text
main
```

Le dépôt utilise désormais la branche `main`.

## 6. Vérification finale de la sécurité

Une dernière vérification des permissions du fichier `.env` a été effectuée :

```bash
stat -c '%A %a %n' .env
```

Résultat obtenu :

```text
-rw------- 600 .env
```

La protection du fichier est toujours effective.

## 7. Vérification de la communication avec Proxmox

Pour confirmer que la configuration Terraform fonctionne toujours avec les variables chargées depuis `.env`, nous avons exécuté :

```bash
terraform plan
```

Résultat obtenu :

```text
proxmox_virtual_environment_vm.vm[0]: Refreshing state... [id=100]
proxmox_virtual_environment_vm.vm[1]: Refreshing state... [id=101]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

**Analyse du résultat :**

- Terraform a actualisé l'état de la VM `srv01`, identifiée par le VMID `100`.
- Terraform a actualisé l'état de la VM `srv02`, identifiée par le VMID `101`.
- La communication avec l'API Proxmox a fonctionné.
- Aucune différence n'a été détectée entre la configuration déclarative et l'infrastructure réelle.
- Aucun changement n'est nécessaire.

Ce test confirme que le chargement des variables depuis `.env` permet toujours à Terraform de communiquer avec Proxmox.

## 8. Bilan de la section

| Opération | État |
|---|---|
| Création du fichier `.env` | Validée |
| Centralisation des variables API | Validée |
| Protection avec `chmod 600` | Validée |
| Chargement avec `source .env` | Validé |
| Vérification des variables | Validée |
| Création du `.gitignore` | Validée |
| Exclusion de `.env` par Git | Validée |
| Initialisation du dépôt Git | Validée |
| Renommage de `master` en `main` | Validé |
| Vérification finale avec `terraform plan` | Validée |

**État du dépôt :** le dépôt Git local est initialisé sur la branche `main`. Aucun commit n'a encore été effectué et aucun dépôt distant n'a encore été configuré.

## 9. Conclusion

Cette section a permis de mettre en place une première couche de sécurisation du projet Terraform.

Les informations d'authentification de l'API Proxmox sont désormais centralisées dans un fichier local protégé par les permissions Linux. Le fichier `.gitignore` empêche son ajout accidentel au suivi Git, tout en excluant les fichiers d'état et les plans Terraform.

Enfin, le test `terraform plan` a confirmé que les deux machines virtuelles restent conformes à leur configuration déclarative et que la communication avec Proxmox fonctionne après cette modification.

**La section 27 est terminée.**