# Section 15 — Configuration du provider Proxmox avec Terraform

## 15.1. Objectif

Après l'initialisation du projet Terraform et l'installation du provider `bpg/proxmox` dans la section 14, nous allons configurer la communication entre Terraform et l'API REST de Proxmox VE.

Cette configuration permettra à Terraform de communiquer avec le serveur Proxmox afin de gérer les ressources de virtualisation.

Les paramètres de notre environnement sont les suivants :

| Paramètre | Valeur |
|---|---|
| Machine d'administration | Kgoumou |
| Serveur Proxmox | pve1 |
| Adresse IP | 192.168.122.32 |
| Port API | 8006 |
| Endpoint API | https://192.168.122.32:8006/ |
| Utilisateur API | terraform@pve |
| Identifiant du token | terraform@pve!terraform-provider |
| Provider Terraform | bpg/proxmox |
| Version du provider | 0.120.0 |

L'authentification repose sur un token API dédié, créé et configuré précédemment dans la section 3.

## 15.2. Vérification de l'accès HTTPS à l'API Proxmox

Avant de configurer le provider Terraform, nous vérifions que la machine `Kgoumou` peut communiquer avec l'API Proxmox en HTTPS.

### Commande exécutée

```bash
curl -v https://192.168.122.32:8006/api2/json/version
```

### Résultat obtenu

Les principaux éléments du résultat sont :

```text
*   Trying 192.168.122.32:8006...
* Connected to 192.168.122.32 (192.168.122.32) port 8006
* SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / RSASSA-PSS
* Server certificate:
*  subject: C=GN; O=KG-LAB; CN=pve1.crg-bank.lan
*  subjectAltName: host "192.168.122.32" matched cert's IP address!
*  issuer: C=GN; O=KG-LAB; CN=KG-LAB Root CA
*  SSL certificate verify ok.
< HTTP/1.1 401 No ticket
* Server: pve-api-daemon/3.0
```

### Analyse technique

Le résultat confirme plusieurs points importants :

- La connexion réseau au serveur Proxmox fonctionne.
- Le port TCP 8006 est accessible.
- La négociation TLS 1.3 s'effectue correctement.
- Le certificat présenté correspond à l'adresse IP utilisée grâce à son SAN.
- Le certificat est signé par notre autorité de certification interne `KG-LAB Root CA`.
- La validation TLS réussit.

La réponse HTTP `401 No ticket` est normale pour cette requête : aucun justificatif d'authentification n'a été transmis avec `curl`.

Il faut donc distinguer deux mécanismes :

- **TLS** assure la sécurisation et l'authentification du serveur.
- **Le token API** permet au client de s'authentifier auprès de Proxmox.

La vérification TLS est donc réussie. L'authentification API sera prise en charge par Terraform.

## 15.3. Vérification des variables d'environnement Proxmox

Avant de définir les paramètres de connexion, nous vérifions si des variables d'environnement commençant par `PROXMOX` sont déjà présentes.

### Commande exécutée

```bash
env | grep '^PROXMOX'
```

### Résultat obtenu

```text
```

Aucune ligne n'a été retournée.

Cela signifie qu'aucune variable d'environnement `PROXMOX` n'était définie dans le nouveau terminal.

Nous allons donc définir les variables nécessaires à la connexion Terraform-Proxmox.

## 15.4. Définition de l'endpoint API Proxmox

L'endpoint correspond à l'adresse HTTPS utilisée par Terraform pour communiquer avec l'API REST de Proxmox.

### Commande exécutée

```bash
export PROXMOX_VE_ENDPOINT="https://192.168.122.32:8006/"
```

### Vérification

```bash
echo "$PROXMOX_VE_ENDPOINT"
```

Résultat obtenu :

```text
https://192.168.122.32:8006/
```

L'endpoint est correctement défini dans la session du terminal.

La commande `export` permet de rendre cette variable disponible aux processus lancés depuis ce terminal, notamment Terraform.

## 15.5. Chargement sécurisé du token API

Dans la section 3, nous avions déjà configuré un utilisateur API, un rôle et un token dédié à Terraform.

Nous reprenons la même méthode de chargement sécurisé du secret.

### 15.5.1. Chargement du secret

Commande exécutée :

```bash
read -rsp "Secret API Token: " PVE_TOKEN_SECRET
echo
```

La commande `read -rsp` permet de saisir le secret sans afficher les caractères dans le terminal.

Le secret est stocké dans la variable `PVE_TOKEN_SECRET`.

### 15.5.2. Définition de l'identifiant du token

Commande exécutée :

```bash
TOKEN_ID='terraform@pve!terraform-provider'
```

Cette variable contient l'identifiant du token API, sans son secret.

### 15.5.3. Construction de la variable attendue par le provider

Commande exécutée :

```bash
export PROXMOX_VE_API_TOKEN="${TOKEN_ID}=${PVE_TOKEN_SECRET}"
```

Le provider attend le token complet sous le format :

```text
IDENTIFIANT_DU_TOKEN=SECRET_DU_TOKEN
```

La variable `PROXMOX_VE_API_TOKEN` rassemble donc l'identifiant et le secret.

### 15.5.4. Vérification du chargement

Afin de vérifier que la variable est définie sans afficher son contenu, nous exécutons :

```bash
if [ -n "$PROXMOX_VE_API_TOKEN" ]; then echo "Token API correctement chargé"; else echo "Token API absent"; fi
```

Résultat obtenu :

```text
Token API correctement chargé
```

Le chargement du token est confirmé.

**Sécurité :** le secret n'est pas inscrit dans les fichiers Terraform et sa valeur complète n'est pas affichée dans le terminal. Les variables exportées restent toutefois limitées à la session et à son environnement de processus ; elles devront être rechargées dans un nouveau terminal.

## 15.6. Création du fichier provider.tf

### Objectif

Le fichier `provider.tf` permet de déclarer et de configurer le provider utilisé par Terraform pour communiquer avec Proxmox VE.

Le provider `bpg/proxmox` récupère automatiquement les paramètres de connexion à partir des variables d'environnement.

### Première configuration proposée

Une première version avait été proposée :

```hcl
provider "proxmox" {
  endpoint  = env("PROXMOX_VE_ENDPOINT")
  api_token = env("PROXMOX_VE_API_TOKEN")
}
```

Après vérification, nous avons corrigé cette configuration : `env()` n'est pas une fonction native utilisable ainsi dans HCL pour lire les variables d'environnement.

Le provider BPG prend directement en charge les variables d'environnement correspondantes.

### Configuration retenue

Commande de création :

```bash
nano provider.tf
```

Contenu final du fichier :

```hcl
provider "proxmox" {}
```

### Explication

Le bloc déclare le provider Proxmox sans inscrire directement les paramètres sensibles dans le fichier.

Le provider récupère automatiquement :

| Variable | Fonction |
|---|---|
| `PROXMOX_VE_ENDPOINT` | Adresse de l'API Proxmox |
| `PROXMOX_VE_API_TOKEN` | Identifiant et secret du token API |

La validation TLS reste activée par défaut. Nous ne désactivons donc pas la vérification du certificat avec un paramètre tel que `insecure = true`.

### Vérification du fichier

Commande exécutée :

```bash
cat provider.tf
```

Résultat obtenu :

```hcl
provider "proxmox" {}
```

Le contenu final est conforme à la configuration retenue.

## 15.7. Validation de la configuration Terraform

Après la création de `provider.tf`, nous vérifions la syntaxe et la cohérence de la configuration.

### Commande exécutée

```bash
terraform validate
```

### Résultat obtenu

```text
Success! The configuration is valid.
```

### Analyse

La validation confirme que :

- Les fichiers Terraform sont correctement structurés.
- Le bloc `provider "proxmox"` est reconnu.
- La configuration ne présente pas d'erreur de syntaxe.
- Le provider déclaré est disponible dans l'environnement initialisé.

Cette commande vérifie la configuration Terraform, mais ne suffit pas à prouver que le token API dispose de toutes les permissions nécessaires à la création des machines virtuelles.

## 15.8. Premier contrôle avec terraform plan

Nous lançons ensuite une première analyse du plan Terraform.

### Commande exécutée

```bash
terraform plan
```

### Résultat obtenu

```text
No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.
```

### Analyse

Le résultat indique que Terraform a terminé l'opération sans erreur et qu'aucune modification n'est proposée.

C'est normal : aucun bloc de ressource n'a encore été déclaré dans le projet.

À ce stade, nous avons préparé et validé la configuration du provider, mais nous n'avons pas encore demandé à Terraform de créer une VM.

Il faut également distinguer ce résultat d'un test complet des permissions : les droits nécessaires à la création des disques et des VM seront réellement sollicités lors des prochaines opérations de déploiement.

## 15.9. État du projet après cette section

Le répertoire du projet contient maintenant les éléments suivants :

```text
terraform-proxmox/
├── images/
│   └── ubuntu-24.04-server-cloudimg-amd64.img
├── .terraform/
├── .terraform.lock.hcl
├── versions.tf
└── provider.tf
```

### Rôle des éléments

| Élément | Fonction |
|---|---|
| `images/` | Stockage local de l'image Ubuntu Cloud Image sur Kgoumou |
| `.terraform/` | Répertoire de travail et providers installés |
| `.terraform.lock.hcl` | Verrouillage des versions et sommes de contrôle des providers |
| `versions.tf` | Déclaration des exigences Terraform et du provider |
| `provider.tf` | Déclaration du provider Proxmox |

## 15.10. Récapitulatif des commandes essentielles

| Opération | Commande |
|---|---|
| Vérifier l'accès HTTPS | `curl -v https://192.168.122.32:8006/api2/json/version` |
| Vérifier les variables Proxmox | `env \| grep '^PROXMOX'` |
| Définir l'endpoint | `export PROXMOX_VE_ENDPOINT="https://192.168.122.32:8006/"` |
| Vérifier l'endpoint | `echo "$PROXMOX_VE_ENDPOINT"` |
| Charger le secret | `read -rsp "Secret API Token: " PVE_TOKEN_SECRET` |
| Définir l'identifiant | `TOKEN_ID='terraform@pve!terraform-provider'` |
| Construire le token complet | `export PROXMOX_VE_API_TOKEN="${TOKEN_ID}=${PVE_TOKEN_SECRET}"` |
| Vérifier le chargement | `if [ -n "$PROXMOX_VE_API_TOKEN" ]; then echo "Token API correctement chargé"; else echo "Token API absent"; fi` |
| Créer le fichier provider | `nano provider.tf` |
| Vérifier le fichier | `cat provider.tf` |
| Valider la configuration | `terraform validate` |
| Analyser le plan | `terraform plan` |

## Conclusion

La configuration initiale du provider Proxmox est terminée.

Les opérations suivantes ont été réalisées :

1. Vérification de la connectivité HTTPS vers Proxmox.
2. Validation du certificat TLS signé par l'autorité interne `KG-LAB Root CA`.
3. Définition de l'endpoint API dans une variable d'environnement.
4. Chargement sécurisé du secret du token API.
5. Construction de la variable `PROXMOX_VE_API_TOKEN`.
6. Création et correction du fichier `provider.tf`.
7. Validation de la configuration avec `terraform validate`.
8. Première analyse avec `terraform plan`, sans erreur et sans changement à appliquer.

La connexion HTTPS et la configuration du provider sont donc préparées. Les permissions de déploiement seront confirmées lors des premières opérations sur les ressources Proxmox.

### Prochaine étape : Section 16 — Déclaration des variables Terraform

Nous préparerons le fichier `variables.tf` pour définir les paramètres des deux machines virtuelles :

- `srv01`
- `srv02`

Nous définirons progressivement leurs caractéristiques : CPU, mémoire, taille du disque, réseau et paramètres Cloud-Init.

Le déploiement restera direct depuis l'image Ubuntu Cloud Image, sans template ni machine virtuelle de référence.