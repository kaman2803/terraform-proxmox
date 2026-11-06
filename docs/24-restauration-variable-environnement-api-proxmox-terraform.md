# Section 24 – Restauration des variables d'environnement et validation du Terraform Plan

## 1. Objectif

Cette section a pour objectif de rétablir les variables d'environnement nécessaires à la connexion entre Terraform, exécuté depuis la machine Ubuntu Kgoumou, et l'API de Proxmox VE.

Lors de la section précédente, le premier `terraform plan` avait échoué parce que la variable `PROXMOX_VE_ENDPOINT` n'était pas définie dans le terminal actuel.

Nous allons donc :

- rétablir l'adresse de l'API Proxmox ;
- vérifier la présence du token API ;
- recharger le token de manière sécurisée ;
- vérifier la disponibilité des variables ;
- relancer `terraform plan` ;
- analyser les deux machines virtuelles prévues.

## 2. Environnement de travail

Les opérations sont réalisées depuis la machine Ubuntu `Kgoumou`.

| Élément | Valeur |
|---|---|
| Machine cliente | Kgoumou |
| Utilisateur Linux | kaman-goumou |
| Répertoire Terraform | `/home/kaman-goumou/lab/terraform-proxmox` |
| Serveur Proxmox | pve1 |
| Adresse IP Proxmox | 192.168.122.32 |
| Port API | 8006 |
| Provider Terraform | bpg/proxmox |
| Version du provider | 0.120.0 |

Le terminal utilisé se trouve dans le répertoire du projet :

```text
kaman-goumou@Kgoumou:~/lab/terraform-proxmox$
```

## 3. Rétablissement de la variable d'environnement PROXMOX_VE_ENDPOINT

### 3.1. Définition de l'endpoint API

Nous avons commencé par rétablir l'adresse de l'API Proxmox dans la variable d'environnement `PROXMOX_VE_ENDPOINT`.

**Commande exécutée :**

```bash
export PROXMOX_VE_ENDPOINT="https://192.168.122.32:8006/"
```

Cette variable indique au provider Terraform l'adresse HTTPS du serveur Proxmox VE.

### 3.2. Vérification de la variable

Nous avons ensuite vérifié que la variable était correctement définie.

**Commande exécutée :**

```bash
echo "$PROXMOX_VE_ENDPOINT"
```

**Résultat obtenu :**

```text
https://192.168.122.32:8006/
```

La variable `PROXMOX_VE_ENDPOINT` est maintenant correctement définie dans le terminal actuel.

## 4. Vérification du token API Proxmox

### 4.1. Contrôle de la présence du token

Nous avons vérifié si la variable `PROXMOX_VE_API_TOKEN` était disponible.

**Commande exécutée :**

```bash
if [ -n "$PROXMOX_VE_API_TOKEN" ]; then echo "Token API présent"; else echo "Token API absent"; fi
```

**Résultat obtenu :**

```text
Token API absent
```

Le résultat confirme que le token API n'était pas chargé dans le terminal actuel.

Il était donc nécessaire de le reconstituer à partir de son identifiant et de son secret.

## 5. Chargement sécurisé du token API

### 5.1. Lecture masquée du secret

Nous avons utilisé la commande `read -rsp` pour saisir le secret du token sans l'afficher dans le terminal.

**Commande exécutée :**

```bash
read -rsp "Secret API Token: " PVE_TOKEN_SECRET
```

La saisie du secret est masquée. Sa valeur n'est volontairement pas reproduite dans cette documentation.

### 5.2. Passage à la ligne suivante

**Commande exécutée :**

```bash
echo
```

Cette commande permet simplement de revenir à la ligne après la saisie masquée.

### 5.3. Définition de l'identifiant du token

Nous avons ensuite défini l'identifiant du token API Proxmox.

**Commande exécutée :**

```bash
TOKEN_ID='terraform@pve!terraform-provider'
```

L'identifiant utilisé correspond au token créé précédemment sur Proxmox VE.

### 5.4. Construction de la variable d'environnement

Nous avons assemblé l'identifiant et le secret selon le format attendu par le provider.

**Commande exécutée :**

```bash
export PROXMOX_VE_API_TOKEN="${TOKEN_ID}=${PVE_TOKEN_SECRET}"
```

La variable contient ainsi l'identifiant et le secret du token API.

### 5.5. Vérification de la présence du token

Pour vérifier que la variable est correctement chargée sans afficher sa valeur, nous avons exécuté :

```bash
if [ -n "$PROXMOX_VE_API_TOKEN" ]; then echo "Token API correctement chargé"; else echo "Token API absent"; fi
```

**Résultat obtenu :**

```text
Token API correctement chargé
```

Le token API est maintenant disponible dans le terminal.

## 6. Vérification des variables d'environnement

À ce stade, les deux variables nécessaires à l'initialisation du provider Proxmox sont disponibles.

| Variable | Fonction | État |
|---|---|---|
| `PROXMOX_VE_ENDPOINT` | Adresse de l'API Proxmox | Présente |
| `PROXMOX_VE_API_TOKEN` | Authentification auprès de l'API | Présente |

Le fichier `provider.tf` conserve sa configuration minimale :

```hcl
provider "proxmox" {}
```

Le provider récupère les informations de connexion à partir des variables d'environnement.

## 7. Exécution du premier Terraform Plan réussi

### 7.1. Lancement de la simulation

Après le rétablissement des variables d'environnement, nous avons relancé la commande de planification Terraform.

**Commande exécutée :**

```bash
terraform plan
```

**Résultat obtenu :**

Terraform a généré le plan d'exécution sans erreur.

Les symboles utilisés dans le plan indiquent les opérations prévues :

```text
+ create
```

Le symbole `+` signifie qu'une nouvelle ressource sera créée.

### 7.2. Première machine virtuelle : srv01

Terraform prévoit la création de la ressource :

```text
proxmox_virtual_environment_vm.vm[0]
```

Nom de la machine virtuelle :

```text
srv01
```

Caractéristiques prévues :

| Paramètre | Valeur |
|---|---|
| Nœud Proxmox | pve1 |
| Nom | srv01 |
| CPU | 1 cœur |
| RAM | 1024 Mio |
| Disque | 15 Gio |
| Stockage | local-lvm |
| Interface disque | scsi0 |
| Contrôleur SCSI | virtio-scsi-pci |
| Image source | Ubuntu Cloud Image 24.04 |
| Réseau | vmbr0 |
| Modèle réseau | virtio |
| IPv4 | DHCP |
| Utilisateur Linux | kaman |
| Authentification | Clé publique SSH |

Le disque sera importé depuis le volume Proxmox suivant :

```text
local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2
```

### 7.3. Deuxième machine virtuelle : srv02

Terraform prévoit également la création de la ressource :

```text
proxmox_virtual_environment_vm.vm[1]
```

Nom de la machine virtuelle :

```text
srv02
```

Caractéristiques prévues :

| Paramètre | Valeur |
|---|---|
| Nœud Proxmox | pve1 |
| Nom | srv02 |
| CPU | 1 cœur |
| RAM | 1024 Mio |
| Disque | 15 Gio |
| Stockage | local-lvm |
| Interface disque | scsi0 |
| Contrôleur SCSI | virtio-scsi-pci |
| Image source | Ubuntu Cloud Image 24.04 |
| Réseau | vmbr0 |
| Modèle réseau | virtio |
| IPv4 | DHCP |
| Utilisateur Linux | kaman |
| Authentification | Clé publique SSH |

La deuxième machine utilise les mêmes paramètres que la première.

### 7.4. Synthèse du plan

À la fin de l'exécution, Terraform a affiché :

```text
Plan: 2 to add, 0 to change, 0 to destroy.
```

Interprétation :

- `2 to add` : deux nouvelles machines virtuelles seront créées.
- `0 to change` : aucune ressource existante ne sera modifiée.
- `0 to destroy` : aucune ressource existante ne sera supprimée.

Le plan prévoit donc uniquement la création de `srv01` et `srv02`.

### 7.5. Avertissement concernant l'option -out

Terraform a également affiché le message suivant :

```text
Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
```

Cela signifie que le plan n'a pas été enregistré dans un fichier avec l'option `-out`.

Si la commande `terraform apply` est exécutée ultérieurement sans fichier de plan sauvegardé, Terraform recalculera les opérations à effectuer.

Pour conserver un plan précis et réutilisable, il est possible de générer un fichier de plan avec :

```bash
terraform plan -out=tfplan
```

Puis de l'appliquer avec :

```bash
terraform apply tfplan
```

Ces deux commandes sont présentées ici à titre explicatif. Elles ne font pas partie des commandes exécutées durant cette section.

## 8. Bilan de la section 24

| Opération | Résultat |
|---|---|
| Rétablissement de PROXMOX_VE_ENDPOINT | Réussi |
| Vérification de l'endpoint | Réussie |
| Vérification initiale du token | Token absent |
| Lecture masquée du secret | Effectuée |
| Définition de TOKEN_ID | Effectuée |
| Construction de PROXMOX_VE_API_TOKEN | Réussie |
| Vérification du token | Réussie |
| Exécution de terraform plan | Réussie |
| Prévision de création de srv01 | Validée dans le plan |
| Prévision de création de srv02 | Validée dans le plan |

<text color="success" weight="semibold">SECTION 24 : VALIDÉE</text>

Les variables d'environnement nécessaires à la connexion API ont été rétablies. Terraform communique correctement avec Proxmox VE et génère un plan prévoyant la création de deux machines virtuelles.

**Aucune machine virtuelle n'a encore été créée.** La commande `terraform apply` n'a pas été exécutée.

## 9. Étape suivante : section 25

La prochaine section portera sur le déploiement effectif des machines virtuelles avec Terraform.

Objectifs :

1. Préparer le plan d'exécution final.
2. Examiner les opérations prévues.
3. Exécuter `terraform apply` après validation.
4. Vérifier le résultat du déploiement sur Proxmox VE.
5. Identifier les VM et leurs identifiants respectifs.

**Nom du prochain fichier :**

`25-deploiement-machines-virtuelles-terraform-apply.md`