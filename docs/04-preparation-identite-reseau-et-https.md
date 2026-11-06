# Section 04 — Préparation de l'identité réseau et vérification HTTPS de Proxmox

## 1. Objectif

Avant de configurer le certificat TLS de Proxmox VE, nous devons garantir que le serveur possède une identité réseau cohérente et que les machines clientes peuvent accéder à son interface HTTPS.

Cette étape concerne trois machines :

| Machine | Système | Rôle |
|---|---|---|
| Proxmox VE | Proxmox VE 9.2.25 | Serveur de virtualisation |
| Kgoumou | Ubuntu 24.04.5 LTS | Administration et exécution de Terraform |
| Mac | macOS | Administration via navigateur Web |

Identité retenue pour le serveur :

- Nom court : `pve1`
- Nom complet (FQDN) : `pve1.crg-bank.lan`
- Adresse IP : `192.168.122.32`
- Port HTTPS : `8006`

## 2. Correction de l'identité du serveur Proxmox

### 2.1. Analyse de la configuration initiale

L'examen du fichier `/etc/hosts` a révélé que le serveur conservait une ancienne identité provenant de son modèle de virtualisation :

```text
127.0.0.1 localhost.localdomain localhost
192.168.122.31 pve.crg-bank.lan pve
```

Or, le nouveau serveur utilise l'adresse IP `192.168.122.32`.

Il existait donc une incohérence entre l'adresse IP actuelle et l'identité héritée de l'ancien modèle.

### 2.2. Modification du nom d'hôte

Commande exécutée :

```bash
hostnamectl set-hostname pve1
```

Un nouveau shell a ensuite été ouvert :

```bash
bash
```

Vérification :

```bash
hostname
```

Résultat obtenu :

```text
pve1
```

### 2.3. Correction du fichier `/etc/hosts`

Commande exécutée :

```bash
nano /etc/hosts
```

L'ancienne entrée a été remplacée par :

```text
127.0.0.1 localhost.localdomain localhost
192.168.122.32 pve1.crg-bank.lan pve1

# The following lines are desirable for IPv6 capable hosts

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
```

### 2.4. Vérification de l'identité locale

Commandes exécutées :

```bash
hostname
hostname -f
getent hosts pve1
```

Résultats obtenus :

```text
root@pve1:~# hostname
pve1

root@pve1:~# hostname -f
pve1.crg-bank.lan

root@pve1:~# getent hosts pve1
192.168.122.32  pve1.crg-bank.lan pve1
```

### 2.5. Explication

- `hostname` affiche le nom court du serveur.
- `hostname -f` affiche son nom complet (FQDN).
- `getent hosts` vérifie la résolution du nom à travers les mécanismes de résolution configurés sur le système.

Les trois vérifications ont confirmé la nouvelle identité du serveur.

## 3. Configuration du fichier hosts sur Kgoumou

La machine Kgoumou doit pouvoir résoudre le nom DNS du serveur Proxmox.

### 3.1. Modification du fichier hosts

Commande exécutée :

```bash
sudo nano /etc/hosts
```

Entrée ajoutée :

```text
# Proxmox lab
192.168.122.32 pve1.crg-bank.lan pve1
```

### 3.2. Vérification

Commande exécutée :

```bash
sudo cat /etc/hosts
```

Résultat observé :

```text
127.0.0.1 localhost
127.0.1.1 Kgoumou

# Proxmox lab
192.168.122.32 pve1.crg-bank.lan pve1

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

### 3.3. Test de résolution

Commande exécutée :

```bash
getent hosts pve1.crg-bank.lan
```

Résultat obtenu :

```text
192.168.122.32  pve1.crg-bank.lan pve1
```

La résolution du nom depuis Ubuntu est validée.

## 4. Configuration du fichier hosts sur macOS

Le Mac doit également pouvoir résoudre le nom du serveur Proxmox.

### 4.1. Modification du fichier hosts

Commande exécutée :

```bash
sudo nano /etc/hosts
```

Entrée ajoutée :

```text
# Proxmox lab
192.168.122.32 pve1.crg-bank.lan pve1
```

### 4.2. Actualisation du cache DNS

Commandes exécutées :

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Ces commandes permettent de vider le cache de résolution et de relancer la prise en compte des informations de résolution sur macOS.

### 4.3. Vérification

Commande exécutée :

```bash
dscacheutil -q host -a name pve1.crg-bank.lan
```

Résultat obtenu :

```text
name: pve1.crg-bank.lan
ip_address: 192.168.122.32
```

La résolution du nom depuis macOS est validée.

## 5. Vérification de l'accès HTTPS depuis les deux clients

Après la configuration des fichiers hosts, nous avons testé l'accès à l'API Proxmox en utilisant le nom DNS retenu.

URL de l'API :

```text
https://pve1.crg-bank.lan:8006/api2/json
```

### 5.1. Test depuis Kgoumou

Commande exécutée :

```bash
curl -k -sS -o /dev/null -w "HTTP Status: %{http_code}\n" \
https://pve1.crg-bank.lan:8006/api2/json
```

Résultat obtenu :

```text
HTTP Status: 401
```

### 5.2. Test depuis le Mac

Commande exécutée :

```bash
curl -k -sS -o /dev/null -w "HTTP Status: %{http_code}\n" \
https://pve1.crg-bank.lan:8006/api2/json
```

Résultat obtenu :

```text
HTTP Status: 401
```

### 5.3. Interprétation

Le code HTTP `401 Unauthorized` est attendu pour cette requête, car aucun identifiant d'authentification n'a été fourni.

Il confirme néanmoins que :

- Le nom `pve1.crg-bank.lan` est correctement résolu depuis les deux clients.
- Les deux clients peuvent atteindre le serveur Proxmox.
- Le service HTTPS répond sur le port `8006`.
- L'API Proxmox est accessible et demande une authentification.

**Important :** l'option `-k` de curl désactive la vérification du certificat TLS. Ces tests valident donc la connectivité HTTPS, mais pas encore la confiance dans le certificat présenté par Proxmox.

## 6. Architecture réseau obtenue

```text
                  LABORATOIRE PROXMOX

              Proxmox VE 9.2.25
              pve1.crg-bank.lan
                192.168.122.32
                      |
                      |
                HTTPS / TCP 8006
                      |
             +--------+--------+
             |                 |
             |                 |
        Kgoumou               Mac
     Ubuntu 24.04.5          macOS
             |                 |
        /etc/hosts         /etc/hosts
             |                 |
             +--------+--------+
                      |
             Résolution locale
                      |
          pve1.crg-bank.lan
             192.168.122.32
```

## 7. Bilan des validations

| Opération | Résultat |
|---|---|
| Modification du hostname Proxmox | Validée |
| Correction de `/etc/hosts` sur Proxmox | Validée |
| Résolution du FQDN sur Proxmox | Validée |
| Configuration de `/etc/hosts` sur Ubuntu | Validée |
| Résolution depuis Kgoumou | Validée |
| Configuration de `/etc/hosts` sur macOS | Validée |
| Résolution depuis le Mac | Validée |
| Accès HTTPS depuis Kgoumou | HTTP 401 |
| Accès HTTPS depuis macOS | HTTP 401 |

## 8. Conclusion

L'identité réseau de Proxmox VE est maintenant cohérente et les deux machines clientes peuvent accéder à son API HTTPS en utilisant le nom `pve1.crg-bank.lan`.

La résolution est actuellement assurée localement par les fichiers `/etc/hosts` des trois machines. Aucun enregistrement DNS centralisé n'a été configuré dans cette étape.

La connectivité HTTPS est validée, mais la vérification de confiance du certificat reste à effectuer.

### Prochaine étape

Nous allons examiner le certificat TLS actuellement présenté par Proxmox, puis créer une autorité de certification interne (CA) et un certificat serveur signé par cette autorité.

Le certificat racine de la CA sera installé dans les magasins de confiance de Kgoumou et du Mac.

**Fichier :** `docs/04-preparation-identite-reseau-et-https.md`

**Capture d'écran suggérée :** `screenshots/04-identite-reseau-et-connectivite-https.png`

La capture devra montrer les résultats de résolution et les tests HTTP depuis les deux clients, sans informations sensibles.