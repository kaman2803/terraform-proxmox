# Section 03 — Création d'un utilisateur dédié, d'un rôle personnalisé et d'un token API Proxmox

## 1. Objectif

Pour permettre à Terraform de communiquer avec Proxmox VE, nous allons mettre en place une authentification dédiée à l'automatisation.

L'objectif est de ne pas utiliser le compte administrateur `root@pam` pour les opérations Terraform.

Cette configuration repose sur quatre éléments :

- **Utilisateur dédié** : `terraform@pve`
- **Rôle personnalisé** : `Terraform`
- **Permissions ACL** : attribution des privilèges à l'utilisateur et au token
- **Token API** : `terraform@pve!terraform-provider`

L'utilisation d'un compte dédié permet de mieux contrôler les autorisations accordées à Terraform.

## 2. Vérification des utilisateurs Proxmox existants

### 2.1. Commande exécutée

```bash
pveum user list
```

### 2.2. Résultat observé

La liste initiale contenait notamment :

- `root@pam` : compte administrateur Proxmox.
- Adresse électronique associée : `kaman@crg-bank.lan`.

### 2.3. Explication

La commande `pveum user list` affiche les utilisateurs connus du système d'authentification Proxmox.

Les domaines d'authentification utilisés ici sont :

- `pam` : authentification basée sur les comptes Linux/PAM.
- `pve` : domaine interne d'authentification Proxmox.

Nous allons créer un utilisateur dans le domaine `pve`.

## 3. Création de l'utilisateur Terraform

### 3.1. Commande exécutée

```bash
pveum user add terraform@pve --comment "Compte dedie a Terraform"
```

### 3.2. Vérification

```bash
pveum user list
```

### 3.3. Résultat observé

L'utilisateur `terraform@pve` apparaît désormais dans la liste avec les informations suivantes :

| Paramètre | Valeur |
|---|---|
| Utilisateur | `terraform@pve` |
| Commentaire | `Compte dedie a Terraform` |
| État | Activé (`1`) |

### 3.4. Explication

L'utilisateur `terraform@pve` est un compte technique destiné aux opérations d'automatisation.

Il sera utilisé pour authentifier Terraform auprès de l'API Proxmox.

Il est préférable de séparer les comptes d'administration humaine des comptes techniques utilisés par les outils d'automatisation.

## 4. Vérification des rôles disponibles

### 4.1. Commande exécutée

```bash
pveum role list
```

### 4.2. Résultat observé

Proxmox proposait notamment les rôles intégrés suivants :

- `Administrator`
- `NoAccess`
- `PVEAdmin`
- `PVEAuditor`
- `PVEDatastoreAdmin`
- `PVEDatastoreUser`
- `PVEPoolAdmin`
- `PVEPoolUser`
- `PVESDNAdmin`
- `PVESDNUser`
- `PVESysAdmin`
- `PVETemplateUser`
- `PVEUserAdmin`
- `PVEVMAdmin`
- `PVEVMUser`

### 4.3. Explication

Un rôle Proxmox regroupe un ensemble de privilèges.

Plutôt que d'attribuer le rôle `Administrator`, nous avons choisi de créer un rôle personnalisé contenant les permissions nécessaires à notre projet Terraform.

Cela permet de limiter les droits du compte technique.

## 5. Création du rôle personnalisé Terraform

### 5.1. Commande exécutée

```bash
pveum role add Terraform -privs "VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.Cloudinit,VM.Config.CPU,VM.Config.Disk,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Config.HWType,VM.PowerMgmt,Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Sys.Audit,SDN.Audit,SDN.Use"
```

### 5.2. Vérification détaillée

```bash
pveum role list --output-format json | python3 -c 'import json,sys; roles=json.load(sys.stdin); print(json.dumps([r for r in roles if r["roleid"]=="Terraform"], indent=2))'
```

### 5.3. Résultat observé

Le rôle `Terraform` a été créé avec les 18 privilèges suivants :

| Catégorie | Privilèges |
|---|---|
| Machines virtuelles | `VM.Allocate`, `VM.Audit`, `VM.Clone` |
| Configuration VM | `VM.Config.CDROM`, `VM.Config.Cloudinit`, `VM.Config.CPU`, `VM.Config.Disk`, `VM.Config.Memory`, `VM.Config.Network`, `VM.Config.Options`, `VM.Config.HWType` |
| Gestion VM | `VM.PowerMgmt` |
| Stockage | `Datastore.AllocateSpace`, `Datastore.AllocateTemplate`, `Datastore.Audit` |
| Système | `Sys.Audit` |
| SDN | `SDN.Audit`, `SDN.Use` |

La sortie JSON a confirmé :

```json
{
  "roleid": "Terraform",
  "special": 0
}
```

La propriété `special: 0` indique qu'il s'agit d'un rôle personnalisé et non d'un rôle système spécial.

### 5.4. Explication des principaux privilèges

- `VM.Allocate` : autorise l'allocation de machines virtuelles.
- `VM.Audit` : permet de consulter les informations des machines virtuelles.
- `VM.Clone` : autorise le clonage d'une machine virtuelle ou d'un template.
- `VM.Config.CPU` : permet de modifier la configuration CPU.
- `VM.Config.Memory` : permet de modifier la mémoire.
- `VM.Config.Disk` : permet de configurer les disques.
- `VM.Config.Network` : permet de configurer les interfaces réseau.
- `VM.Config.Cloudinit` : permet de modifier les paramètres Cloud-Init.
- `VM.PowerMgmt` : permet de gérer l'alimentation des machines virtuelles.
- `Datastore.AllocateSpace` : autorise l'allocation d'espace sur un stockage.
- `Datastore.Audit` : permet de consulter les informations des stockages.

Ces permissions correspondent aux opérations envisagées pour le clonage et la configuration de machines virtuelles avec Terraform.

## 6. Attribution du rôle à l'utilisateur

### 6.1. Commande exécutée

```bash
pveum acl modify / --user terraform@pve --role Terraform
```

### 6.2. Vérification

```bash
pveum acl list
```

### 6.3. Résultat observé

| Paramètre | Valeur |
|---|---|
| Chemin ACL | `/` |
| Rôle | `Terraform` |
| Type | `user` |
| Utilisateur | `terraform@pve` |
| Propagation | `1` |

### 6.4. Explication

Une ACL (*Access Control List*) permet d'attribuer des permissions à un utilisateur ou à un token sur une partie de l'arborescence Proxmox.

Le chemin `/` représente la racine de l'arborescence des permissions Proxmox.

La valeur `propagate=1` signifie que les permissions sont propagées aux éléments descendants.

**Point de sécurité :** cette attribution à la racine donne au compte une portée étendue sur l'environnement Proxmox. Pour un environnement de production, il sera préférable d'étudier une attribution plus restrictive, adaptée aux ressources réellement gérées par Terraform.

## 7. Création du token API

### 7.1. Commande exécutée

```bash
pveum user token add terraform@pve terraform-provider --privsep 1
```

### 7.2. Résultat observé

Proxmox a créé le token avec les informations suivantes :

| Paramètre | Valeur |
|---|---|
| Utilisateur associé | `terraform@pve` |
| Identifiant du token | `terraform-provider` |
| Identifiant complet | `terraform@pve!terraform-provider` |
| Privilege Separation | `1` |
| Expiration | `0` |

Proxmox a également affiché une valeur secrète lors de la création.

**Important :** cette valeur secrète ne doit pas être publiée dans GitHub, dans les captures d'écran ou dans la documentation du projet.

Elle doit être conservée dans un emplacement sécurisé.

### 7.3. Explication du token API

Un token API permet à une application externe de s'authentifier auprès de Proxmox sans utiliser directement le mot de passe du compte utilisateur.

Dans notre projet :

- Terraform est le client API.
- Proxmox VE est le serveur API.
- `terraform@pve` est l'utilisateur associé.
- `terraform-provider` est le nom du token.

L'identifiant complet du token est composé de l'utilisateur, du séparateur `!` et du nom du token.

### 7.4. Vérification du token

Commande exécutée :

```bash
pveum user token list terraform@pve
```

Résultat observé :

| Paramètre | Valeur |
|---|---|
| Token | `terraform-provider` |
| Expiration | `0` |
| Privilege Separation | `1` |

La valeur `expire=0` indique que le token n'a pas de date d'expiration configurée.

Il conviendra de réévaluer cette durée de validité selon les exigences de sécurité de l'environnement.

## 8. Attribution des permissions au token

### 8.1. Commande exécutée

```bash
pveum acl modify / --token 'terraform@pve!terraform-provider' --role Terraform
```

### 8.2. Vérification

```bash
pveum acl list
```

### 8.3. Résultat observé

Deux entrées étaient présentes :

| Type | Identifiant | Rôle | Chemin |
|---|---|---|---|
| user | `terraform@pve` | `Terraform` | `/` |
| token | `terraform@pve!terraform-provider` | `Terraform` | `/` |

### 8.4. Explication : Privilege Separation

Lors de la création du token, nous avons utilisé :

```bash
--privsep 1
```

Cette option active la séparation des privilèges (*Privilege Separation*).

Avec cette configuration, le token possède ses propres permissions ACL, indépendamment de celles de son utilisateur associé.

Il était donc nécessaire d'attribuer explicitement le rôle `Terraform` au token.

L'utilisateur et le token disposent ainsi chacun de leur entrée ACL.

## 9. Test d'authentification API depuis Kgoumou

Une fois l'utilisateur, le rôle et le token configurés sur Proxmox, nous avons effectué un test depuis la machine Ubuntu `Kgoumou`.

### 9.1. Chargement sécurisé du secret

```bash
read -rsp "Secret API Token: " PVE_TOKEN_SECRET
echo
```

Cette commande demande le secret sans l'afficher dans le terminal.

### 9.2. Définition de l'identifiant du token

```bash
TOKEN_ID='terraform@pve!terraform-provider'
```

### 9.3. Test de l'API Proxmox

Commande exécutée :

```bash
curl -k -sS -w '\nHTTP Status: %{http_code}\n' \
  -H "Authorization: PVEAPIToken=${TOKEN_ID}=${PVE_TOKEN_SECRET}" \
  https://192.168.122.32:8006/api2/json/version
```

### 9.4. Résultat réel obtenu

```json
{
  "data": {
    "release": "9.2",
    "version": "9.2.25",
    "repoid": "88a31f5fd94aab6d"
  }
}
```

Code HTTP retourné :

```text
HTTP Status: 200
```

### 9.5. Explication du résultat

Le code HTTP `200` indique que la requête a été traitée avec succès.

La réponse JSON confirme les informations suivantes :

| Paramètre | Valeur |
|---|---|
| Release | `9.2` |
| Version Proxmox VE | `9.2.25` |
| Repo ID | `88a31f5fd94aab6d` |
| Résultat HTTP | `200 OK` |

Nous avons donc validé l'authentification du token API depuis `Kgoumou`.

L'option `-k` de curl désactive la vérification du certificat TLS. Elle a été utilisée ici pour le test dans notre laboratoire, car le certificat présenté par le nouveau serveur Proxmox possède encore le nom `pve.crg-bank.lan`, hérité de l'ancienne machine modèle.

Pour une configuration sécurisée, il faudra ensuite mettre en place une validation TLS correcte, avec un certificat correspondant au nom réellement utilisé ou une autorité de certification de confiance.

### 9.6. Nettoyage des variables

Après le test, les variables contenant les informations sensibles ont été supprimées de la session :

```bash
unset PVE_TOKEN_SECRET
```

Lors du test final, l'identifiant du token était également stocké dans la variable `TOKEN_ID`. Il est recommandé de supprimer les deux variables :

```bash
unset PVE_TOKEN_SECRET TOKEN_ID
```

## 10. Architecture d'authentification obtenue

Le fonctionnement de l'authentification peut être représenté ainsi :

```text
                 MACHINE ADMINISTRATIVE
                       Kgoumou
                  Ubuntu 24.04.5 LTS
                          |
                          |
                       Terraform
                          |
                          | HTTPS / TCP 8006
                          |
                 API Proxmox VE
                  192.168.122.32
                          |
                          |
                Authentification API
                          |
                          |
                 terraform@pve
                          |
                          |
             terraform@pve!terraform-provider
                          |
                          |
                 ACL : rôle Terraform
                          |
                          |
              Permissions Proxmox définies
```

## 11. Bilan de la section 03

Les opérations suivantes ont été réalisées et validées :

| Opération | Résultat |
|---|---|
| Création de l'utilisateur `terraform@pve` | Validée |
| Création du rôle personnalisé `Terraform` | Validée |
| Définition des 18 privilèges | Validée |
| Attribution du rôle à l'utilisateur | Validée |
| Création du token API | Validée |
| Activation de la séparation des privilèges | Validée |
| Attribution du rôle au token | Validée |
| Authentification depuis Kgoumou | HTTP 200 |

**Conclusion :** l'authentification entre Terraform et l'API Proxmox VE est maintenant fonctionnelle. La prochaine étape consistera à identifier le template Ubuntu Cloud-Init existant sur Proxmox, son VMID et son stockage, afin de préparer le clonage automatisé des machines virtuelles avec Terraform.

---

**Fichier :** `docs/03-creation-utilisateur-role-et-token-api-proxmox.md`

**Capture d'écran à prévoir :** `screenshots/03-creation-utilisateur-role-token-api.png`

Veiller à masquer le secret du token et toute information sensible avant de réaliser ou de publier les captures.