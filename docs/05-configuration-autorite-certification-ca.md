# Section 05 — Configuration de l'autorité de certification interne (CA)

## 1. Objectif

L'objectif de cette section est de créer une autorité de certification privée (CA) pour sécuriser les communications HTTPS avec Proxmox VE.

Cette autorité sera utilisée pour signer le futur certificat TLS du serveur :

| Paramètre | Valeur |
|---|---|
| Serveur | Proxmox VE |
| Nom DNS | `pve1.crg-bank.lan` |
| Adresse IP | `192.168.122.32` |
| Port HTTPS | `8006` |
| Autorité de certification | `KG-LAB Root CA` |
| Machine hébergeant la CA | Kgoumou |
| Système | Ubuntu 24.04.5 LTS |

Le certificat racine de notre CA sera ensuite installé dans les magasins de confiance de Kgoumou et du Mac.

La clé privée de la CA restera exclusivement sur Kgoumou.

## 2. Vérification de la disponibilité d'OpenSSL

OpenSSL est l'outil utilisé pour générer les clés cryptographiques et les certificats X.509.

### 2.1. Commande exécutée

```bash
openssl version
```

### 2.2. Résultat obtenu

```text
OpenSSL 3.0.13 30 Jan 2024 (Library: OpenSSL 3.0.13 30 Jan 2024)
```

### 2.3. Explication

OpenSSL permet notamment de :

- Générer des clés privées et publiques.
- Créer des demandes de signature de certificats (CSR).
- Générer des certificats X.509.
- Signer des certificats.
- Vérifier les chaînes de confiance.

La version installée sur Kgoumou est OpenSSL 3.0.13.

## 3. Création de l'arborescence de la CA

Nous avons choisi de stocker notre autorité de certification dans le répertoire personnel de l'utilisateur `kaman-goumou`.

### 3.1. Commande exécutée

```bash
mkdir -p ~/ca-proxmox/{certs,crl,csr,private,newcerts}
```

### 3.2. Vérification

```bash
tree ~/ca-proxmox
```

### 3.3. Résultat obtenu

```text
/home/kaman-goumou/ca-proxmox
├── certs
├── crl
├── csr
├── newcerts
└── private

6 directories, 0 files
```

### 3.4. Explication de la structure

| Répertoire | Fonction |
|---|---|
| `certs/` | Stockage des certificats publics |
| `crl/` | Stockage des listes de révocation de certificats |
| `csr/` | Stockage des demandes de signature de certificats |
| `private/` | Stockage des clés privées |
| `newcerts/` | Archivage des certificats émis |

Cette organisation permet de séparer les éléments privés des éléments publics de notre CA.

## 4. Sécurisation des répertoires

Avant de générer la clé privée, nous avons restreint l'accès au répertoire principal et au répertoire contenant les clés privées.

### 4.1. Commande exécutée

```bash
chmod 700 ~/ca-proxmox ~/ca-proxmox/private
```

### 4.2. Vérification

```bash
stat -c '%A %a %n' ~/ca-proxmox ~/ca-proxmox/private
```

### 4.3. Résultat obtenu

```text
drwx------ 700 /home/kaman-goumou/ca-proxmox
drwx------ 700 /home/kaman-goumou/ca-proxmox/private
```

### 4.4. Explication

La permission `700` signifie :

- Propriétaire : lecture, écriture et exécution.
- Groupe : aucun droit.
- Autres utilisateurs : aucun droit.

Seul l'utilisateur propriétaire peut accéder à ces répertoires.

## 5. Génération de la clé privée de la CA

La clé privée constitue l'élément cryptographique le plus sensible de notre autorité de certification.

Nous avons choisi l'algorithme RSA avec une longueur de clé de 4096 bits.

### 5.1. Commande exécutée

```bash
openssl genrsa -out ~/ca-proxmox/private/ca.key.pem 4096
```

Cette commande génère une clé privée RSA de 4096 bits.

### 5.2. Sécurisation de la clé

```bash
chmod 400 ~/ca-proxmox/private/ca.key.pem
```

### 5.3. Vérification

```bash
stat -c '%A %a %s bytes %n' ~/ca-proxmox/private/ca.key.pem
```

### 5.4. Résultat obtenu

```text
-r-------- 400 3272 bytes /home/kaman-goumou/ca-proxmox/private/ca.key.pem
```

### 5.5. Explication

| Paramètre | Valeur |
|---|---|
| Fichier | `ca.key.pem` |
| Algorithme | RSA |
| Taille de clé | 4096 bits |
| Taille du fichier | 3272 octets |
| Permissions | `400` |

La permission `400` autorise uniquement le propriétaire à lire le fichier.

**Règle de sécurité :** cette clé ne doit jamais être publiée sur GitHub, transférée sur Proxmox ou copiée sur le Mac.

## 6. Création du certificat racine de la CA

Après la génération de la clé privée, nous avons créé le certificat racine auto-signé de notre autorité de certification.

### 6.1. Paramètres retenus

| Paramètre | Valeur |
|---|---|
| Common Name | `KG-LAB Root CA` |
| Organisation | `KG-LAB` |
| Pays | `GN` |
| Algorithme | RSA |
| Taille de clé | 4096 bits |
| Fonction | Autorité de certification racine |
| Validité | 3650 jours |

### 6.2. Commande exécutée

```bash
openssl req -x509 -new -nodes \
  -key ~/ca-proxmox/private/ca.key.pem \
  -sha256 \
  -days 3650 \
  -out ~/ca-proxmox/certs/ca.crt.pem \
  -subj "/C=GN/O=KG-LAB/CN=KG-LAB Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "subjectKeyIdentifier=hash"
```

### 6.3. Explication des paramètres

| Option | Fonction |
|---|---|
| `req` | Gestion des demandes de certificats |
| `-x509` | Génération directe d'un certificat X.509 |
| `-new` | Création d'un nouveau certificat |
| `-nodes` | Ne pas chiffrer la clé privée dans cette opération |
| `-key` | Utilisation de la clé privée existante |
| `-sha256` | Utilisation de SHA-256 |
| `-days 3650` | Validité de 3650 jours |
| `-out` | Fichier de sortie du certificat |
| `-subj` | Définition de l'identité du certificat |
| `basicConstraints` | Définition du rôle d'autorité de certification |
| `keyUsage` | Définition des usages autorisés |
| `subjectKeyIdentifier` | Identification de la clé publique |

Le fichier créé est :

`~/ca-proxmox/certs/ca.crt.pem`

Ce fichier contient le certificat public de notre autorité de certification.

## 7. Vérification de l'identité et de la validité du certificat

### 7.1. Commande exécutée

```bash
openssl x509 -in ~/ca-proxmox/certs/ca.crt.pem -noout -subject -issuer -dates
```

### 7.2. Résultat obtenu

```text
subject=C = GN, O = KG-LAB, CN = KG-LAB Root CA
issuer=C = GN, O = KG-LAB, CN = KG-LAB Root CA
notBefore=Nov  4 01:00:54 2026 GMT
notAfter=Nov  1 01:00:54 2036 GMT
```

### 7.3. Interprétation

| Élément | Valeur |
|---|---|
| Sujet | `KG-LAB Root CA` |
| Émetteur | `KG-LAB Root CA` |
| Début de validité | 4 novembre 2026 |
| Fin de validité | 1er novembre 2036 |

Le sujet et l'émetteur étant identiques, le certificat est auto-signé.

## 8. Vérification des extensions X.509

Un certificat racine doit être explicitement déclaré comme autorité de certification.

### 8.1. Commande exécutée

```bash
openssl x509 -in ~/ca-proxmox/certs/ca.crt.pem -noout -text | grep -A3 "Basic Constraints"
```

### 8.2. Résultat obtenu

```text
X509v3 Basic Constraints: critical
    CA:TRUE
X509v3 Key Usage: critical
    Certificate Sign, CRL Sign
```

### 8.3. Explication

- `CA:TRUE` : indique que le certificat représente une autorité de certification.
- `Certificate Sign` (`keyCertSign`) : autorise la signature d'autres certificats.
- `CRL Sign` (`cRLSign`) : autorise la signature des listes de révocation.

Les extensions nécessaires à notre CA racine sont présentes.

## 9. Vérification cryptographique de la correspondance des clés

La dernière vérification consiste à confirmer que la clé publique contenue dans le certificat racine correspond à celle dérivée de notre clé privée.

### 9.1. Extraction de la clé publique depuis la clé privée

Commande exécutée :

```bash
openssl pkey -in ~/ca-proxmox/private/ca.key.pem -pubout -outform PEM | sha256sum
```

Résultat obtenu :

```text
e75f2805f23d1f6018aad8b2c9fa77e6549f91a9243818fa407ce9865496735e  -
```

### 9.2. Extraction de la clé publique depuis le certificat

Commande exécutée :

```bash
openssl x509 -in ~/ca-proxmox/certs/ca.crt.pem -pubkey -noout | sha256sum
```

Résultat obtenu :

```text
e75f2805f23d1f6018aad8b2c9fa77e6549f91a9243818fa407ce9865496735e  -
```

### 9.3. Interprétation

Les deux empreintes SHA-256 sont identiques.

Cela confirme que :

- La clé privée et le certificat racine correspondent.
- Le certificat racine contient bien la clé publique associée à notre clé privée.
- La cohérence cryptographique de notre autorité de certification est vérifiée.

## 10. Arborescence finale de la CA

À ce stade, les éléments effectivement créés sont :

```text
/home/kaman-goumou/ca-proxmox/
├── certs/
│   └── ca.crt.pem
├── crl/
├── csr/
├── newcerts/
└── private/
    └── ca.key.pem
```

## 11. Bilan de la section 05

| Opération | Résultat |
|---|---|
| Vérification d'OpenSSL 3.0.13 | Validée |
| Création de l'arborescence CA | Validée |
| Sécurisation des répertoires | Validée |
| Génération de la clé RSA 4096 bits | Validée |
| Protection de la clé privée avec permission 400 | Validée |
| Création du certificat racine auto-signé | Validée |
| Vérification des dates et de l'identité | Validée |
| Vérification de `CA:TRUE` | Validée |
| Vérification des usages de signature | Validée |
| Correspondance cryptographique des clés | Validée |

## 12. Conclusion

L'autorité de certification privée **KG-LAB Root CA** a été créée avec succès sur Kgoumou.

Elle dispose maintenant :

- D'une clé privée RSA de 4096 bits, protégée par des permissions strictes.
- D'un certificat racine X.509 auto-signé, valide pour dix ans.
- Des extensions nécessaires pour signer des certificats.

La correspondance entre la clé privée et le certificat a été confirmée par comparaison de leurs empreintes SHA-256.

La clé privée de la CA restera exclusivement sur Kgoumou.

### Prochaine étape : création du certificat TLS de Proxmox

Nous allons préparer une clé privée distincte pour Proxmox, puis une demande de signature de certificat (CSR).

Le futur certificat serveur devra contenir :

- `DNS:pve1.crg-bank.lan`
- `IP:192.168.122.32`
- L'usage étendu `serverAuth`

Il sera ensuite signé par notre CA interne et installé sur Proxmox VE.

**Fichier :** `docs/05-configuration-autorite-certification-ca.md`

**Capture d'écran suggérée :** `screenshots/05-creation-et-validation-ca.png`

Ne jamais inclure le contenu de `ca.key.pem` dans les captures ou dans le dépôt GitHub.