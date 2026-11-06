# Section 06 — Création du certificat TLS du serveur Proxmox VE

## 1. Objectif

Après la création de notre autorité de certification interne `KG-LAB Root CA`, nous allons générer un certificat TLS destiné au serveur Proxmox VE.

Ce certificat permettra aux clients de vérifier l'identité du serveur lors des connexions HTTPS.

### Identité du serveur

| Paramètre | Valeur |
|---|---|
| Nom court | `pve1` |
| Nom DNS complet | `pve1.crg-bank.lan` |
| Adresse IP | `192.168.122.32` |
| Port HTTPS | `8006` |
| Autorité de certification | `KG-LAB Root CA` |
| Algorithme | RSA |
| Taille des clés | 4096 bits |

Le certificat devra prendre en charge deux modes d'accès :

- Par nom DNS : `pve1.crg-bank.lan`
- Par adresse IP : `192.168.122.32`

Pour cela, nous utiliserons l'extension SAN (*Subject Alternative Name*).

## 2. Génération de la clé privée du serveur

La première opération consiste à générer une clé privée RSA dédiée au serveur Proxmox.

Cette clé est distincte de celle de l'autorité de certification.

### 2.1. Commande exécutée

```bash
openssl genrsa \
  -out ~/ca-proxmox/private/pve1.key.pem \
  4096
```

### 2.2. Protection de la clé privée

```bash
chmod 400 ~/ca-proxmox/private/pve1.key.pem
```

### 2.3. Vérification

```bash
stat -c '%A %a %s bytes %n' ~/ca-proxmox/private/pve1.key.pem
```

### 2.4. Résultat obtenu

```text
-r-------- 400 3272 bytes /home/kaman-goumou/ca-proxmox/private/pve1.key.pem
```

### 2.5. Explication

| Paramètre | Valeur |
|---|---|
| Fichier | `pve1.key.pem` |
| Algorithme | RSA |
| Taille de clé | 4096 bits |
| Taille du fichier | 3272 octets |
| Permissions | `400` |

La permission `400` signifie que seul le propriétaire peut lire le fichier.

Cette clé privée sera utilisée par le service HTTPS de Proxmox.

Elle ne doit jamais être publiée sur GitHub.

## 3. Création de la demande de signature (CSR)

Après la génération de la clé privée, nous avons créé une demande de signature de certificat, appelée CSR (*Certificate Signing Request*).

La CSR contient notamment l'identité du serveur et sa clé publique.

### 3.1. Commande exécutée

```bash
openssl req -new \
  -key ~/ca-proxmox/private/pve1.key.pem \
  -out ~/ca-proxmox/csr/pve1.csr.pem \
  -subj "/C=GN/O=KG-LAB/CN=pve1.crg-bank.lan"
```

### 3.2. Vérification de la CSR

```bash
openssl req -in ~/ca-proxmox/csr/pve1.csr.pem -noout -subject -verify
```

### 3.3. Résultat obtenu

```text
Certificate request self-signature verify OK
subject=C = GN, O = KG-LAB, CN = pve1.crg-bank.lan
```

### 3.4. Explication

- `req -new` : crée une nouvelle demande de certificat.
- `-key` : utilise la clé privée du serveur.
- `-out` : définit le fichier de sortie de la CSR.
- `-subj` : définit l'identité du serveur.

Le message `Certificate request self-signature verify OK` confirme que la signature de la demande est valide.

Le sujet du certificat est :

`CN=pve1.crg-bank.lan`

## 4. Configuration des extensions X.509

Avant de signer la CSR, nous avons préparé un fichier contenant les extensions du futur certificat serveur.

### 4.1. Création du fichier

Commande exécutée :

```bash
nano ~/ca-proxmox/csr/pve1.ext
```

### 4.2. Contenu du fichier

```ini
[ v3_server ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ alt_names ]
DNS.1 = pve1.crg-bank.lan
IP.1 = 192.168.122.32
```

### 4.3. Vérification

```bash
cat ~/ca-proxmox/csr/pve1.ext
```

Le résultat affiché correspond au contenu configuré ci-dessus.

### 4.4. Explication des extensions

| Extension | Fonction |
|---|---|
| `basicConstraints = CA:FALSE` | Indique que le serveur n'est pas une autorité de certification |
| `keyUsage` | Définit les usages cryptographiques de la clé |
| `digitalSignature` | Autorise la signature numérique |
| `keyEncipherment` | Autorise le chiffrement de clé |
| `extendedKeyUsage = serverAuth` | Définit l'utilisation du certificat pour l'authentification serveur |
| `subjectAltName` | Déclare les identités DNS et IP du serveur |
| `subjectKeyIdentifier` | Identifie la clé publique du serveur |
| `authorityKeyIdentifier` | Identifie l'autorité ayant signé le certificat |

### 4.5. Importance du SAN

L'extension SAN est essentielle pour l'identification du serveur par les navigateurs et les clients TLS modernes.

Dans notre cas, elle contient :

```text
DNS:pve1.crg-bank.lan
IP Address:192.168.122.32
```

Ainsi, le certificat pourra être vérifié lorsque l'accès est effectué par le nom DNS ou directement par l'adresse IP.

## 5. Signature de la CSR par KG-LAB Root CA

Après la configuration des extensions, nous avons utilisé notre autorité de certification pour signer la demande.

### 5.1. Commande exécutée

```bash
openssl x509 -req \
  -in ~/ca-proxmox/csr/pve1.csr.pem \
  -CA ~/ca-proxmox/certs/ca.crt.pem \
  -CAkey ~/ca-proxmox/private/ca.key.pem \
  -CAcreateserial \
  -out ~/ca-proxmox/certs/pve1.crt.pem \
  -days 825 \
  -sha256 \
  -extfile ~/ca-proxmox/csr/pve1.ext \
  -extensions v3_server
```

### 5.2. Résultat obtenu

```text
Certificate request self-signature ok
subject=C = GN, O = KG-LAB, CN = pve1.crg-bank.lan
```

La commande a généré le certificat serveur :

`~/ca-proxmox/certs/pve1.crt.pem`

### 5.3. Explication des paramètres

| Paramètre | Fonction |
|---|---|
| `-req` | Utilise une CSR existante |
| `-in` | Indique la CSR à signer |
| `-CA` | Désigne le certificat racine |
| `-CAkey` | Désigne la clé privée de la CA |
| `-CAcreateserial` | Crée le fichier de numéro de série |
| `-out` | Définit le certificat généré |
| `-days 825` | Définit la validité du certificat |
| `-sha256` | Utilise SHA-256 |
| `-extfile` | Charge le fichier d'extensions |
| `-extensions` | Applique la section `v3_server` |

La signature est effectuée sur Kgoumou. La clé privée de la CA n'est donc pas transférée sur Proxmox.

## 6. Vérification de l'identité et de la validité du certificat

### 6.1. Commande exécutée

```bash
openssl x509 -in ~/ca-proxmox/certs/pve1.crt.pem \
  -noout -subject -issuer -dates -serial
```

### 6.2. Résultat obtenu

```text
subject=C = GN, O = KG-LAB, CN = pve1.crg-bank.lan
issuer=C = GN, O = KG-LAB, CN = KG-LAB Root CA
notBefore=Nov  4 01:08:33 2026 GMT
notAfter=Feb  6 01:08:33 2029 GMT
serial=260104A2134A5FFDBB1360DDEECBCDF9F7506202
```

### 6.3. Interprétation

| Paramètre | Valeur |
|---|---|
| Sujet | `pve1.crg-bank.lan` |
| Émetteur | `KG-LAB Root CA` |
| Début de validité | 04 novembre 2026 |
| Fin de validité | 06 février 2029 |
| Validité configurée | 825 jours |
| Numéro de série | `260104A2134A5FFDBB1360DDEECBCDF9F7506202` |

L'émetteur étant `KG-LAB Root CA`, le certificat serveur a bien été signé par notre autorité interne.

## 7. Vérification des extensions X.509

### 7.1. Commande exécutée

```bash
openssl x509 -in ~/ca-proxmox/certs/pve1.crt.pem \
  -noout -text | grep -A3 -E "Basic Constraints|Key Usage|Extended Key Usage|Subject Alternative Name"
```

### 7.2. Résultat obtenu

```text
X509v3 Basic Constraints: critical
    CA:FALSE
X509v3 Key Usage: critical
    Digital Signature, Key Encipherment
X509v3 Extended Key Usage:
    TLS Web Server Authentication
X509v3 Subject Alternative Name:
    DNS:pve1.crg-bank.lan, IP Address:192.168.122.32
X509v3 Subject Key Identifier:
    26:4E:1C:62:E5:61:59:E6:52:9D:2C:59:D6:0E:CE:DE:38:18:7E:D6
```

### 7.3. Interprétation

Les extensions attendues sont présentes :

- `CA:FALSE` : le certificat est destiné à un serveur, pas à une CA.
- `Digital Signature` : autorise la signature numérique.
- `Key Encipherment` : autorise le chiffrement de clé.
- `TLS Web Server Authentication` : autorise l'authentification serveur TLS.
- `DNS:pve1.crg-bank.lan` : identité DNS du serveur.
- `IP Address:192.168.122.32` : identité IP du serveur.

Le certificat possède donc les identités et usages prévus.

## 8. Vérification de la chaîne de confiance

La dernière vérification consiste à confirmer que le certificat serveur est reconnu par notre certificat racine.

### 8.1. Commande exécutée

```bash
openssl verify -CAfile ~/ca-proxmox/certs/ca.crt.pem \
  ~/ca-proxmox/certs/pve1.crt.pem
```

### 8.2. Résultat obtenu

```text
/home/kaman-goumou/ca-proxmox/certs/pve1.crt.pem: OK
```

### 8.3. Explication

Le résultat `OK` confirme que le certificat serveur peut être vérifié à partir du certificat racine `KG-LAB Root CA`.

La chaîne de confiance est donc validée.

## 9. Arborescence des fichiers générés

À la fin de cette section, les fichiers concernés sont :

```text
/home/kaman-goumou/ca-proxmox/
├── certs/
│   ├── ca.crt.pem
│   ├── ca.srl
│   └── pve1.crt.pem
├── crl/
├── csr/
│   ├── pve1.csr.pem
│   └── pve1.ext
├── newcerts/
└── private/
    ├── ca.key.pem
    └── pve1.key.pem
```

Le fichier `ca.srl` est créé automatiquement par OpenSSL avec l'option `-CAcreateserial`. Il contient le numéro de série utilisé pour la signature.

## 10. Bilan de la section 06

| Opération | Résultat |
|---|---|
| Génération de la clé privée du serveur | Validée |
| Protection de la clé privée | Validée |
| Création de la CSR | Validée |
| Vérification de la CSR | Validée |
| Configuration des extensions X.509 | Validée |
| Signature par KG-LAB Root CA | Validée |
| Vérification de l'identité du certificat | Validée |
| Vérification du SAN DNS et IP | Validée |
| Vérification de la chaîne de confiance | Validée |

## 11. Conclusion

Le certificat TLS destiné au serveur Proxmox VE a été généré et signé avec succès par notre autorité de certification interne `KG-LAB Root CA`.

Le certificat prend en charge les deux identités suivantes :

- `pve1.crg-bank.lan`
- `192.168.122.32`

La vérification cryptographique avec OpenSSL a retourné `OK`.

Les fichiers suivants sont maintenant prêts pour la prochaine étape :

- `pve1.crt.pem` : certificat public du serveur.
- `pve1.key.pem` : clé privée du serveur.
- `ca.crt.pem` : certificat racine public de notre CA.

**La clé privée `ca.key.pem` restera exclusivement sur Kgoumou.**

### Prochaine étape — Installation du certificat sur Proxmox VE

Nous allons sauvegarder les certificats actuels de Proxmox, transférer les nouveaux fichiers et installer le certificat dans le répertoire approprié de Proxmox VE.

Nous vérifierons ensuite le service `pveproxy` et l'accès HTTPS sans désactiver la validation TLS.

**Fichier :** `docs/06-creation-certificat-tls-proxmox.md`

**Capture d'écran suggérée :** `screenshots/06-creation-et-validation-certificat-pve1.png`

Ne jamais inclure les clés privées dans les captures d'écran ou dans le dépôt GitHub.