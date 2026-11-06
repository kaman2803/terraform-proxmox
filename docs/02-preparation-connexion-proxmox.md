# Section 02 — Préparation de la connexion entre Kgoumou et Proxmox VE 9.2

## 1. Objectif

Cette section consiste à vérifier la connectivité réseau entre la machine d'administration Kgoumou et le serveur Proxmox VE 9.2.

L'objectif est de s'assurer que Terraform pourra communiquer avec Proxmox à travers son API REST HTTPS, accessible sur le port TCP 8006.

Les vérifications portent sur :

- La connectivité IP entre les deux machines.
- L'accessibilité de l'API HTTPS Proxmox.
- Le certificat TLS présenté par le serveur.
- L'identification du nœud Proxmox.
- L'état du service `pveproxy`.
- L'écoute du port TCP 8006.

## 2. Architecture de communication

L'architecture de communication utilisée pour ce projet est la suivante :

```text
┌─────────────────────────────────────┐
│              Kgoumou                │
│                                     │
│       Ubuntu 24.04.5 LTS            │
│       Terraform 1.17.1              │
│       tfenv 3.2.2                   │
│                                     │
└──────────────────┬──────────────────┘
                   │
                   │ HTTPS
                   │ TCP 8006
                   │ API REST
                   │
                   ▼
┌─────────────────────────────────────┐
│            Proxmox VE               │
│                                     │
│       IP : 192.168.122.32           │
│       Hostname : pve                │
│       Version : 9.2.25              │
│                                     │
│       Service : pveproxy            │
│       Port : TCP 8006               │
│                                     │
└─────────────────────────────────────┘
```

## 3. Vérification de la connectivité réseau

La première opération consiste à vérifier que Kgoumou peut communiquer avec le serveur Proxmox.

### 3.1. Test ICMP avec ping

Commande exécutée depuis Kgoumou :

```bash
ping -c 4 192.168.122.32
```

Résultat obtenu :

```text
PING 192.168.122.32 (192.168.122.32) 56(84) bytes of data.
64 bytes from 192.168.122.32: icmp_seq=1 ttl=64 time=0.319 ms
64 bytes from 192.168.122.32: icmp_seq=2 ttl=64 time=0.287 ms
64 bytes from 192.168.122.32: icmp_seq=3 ttl=64 time=0.321 ms
64 bytes from 192.168.122.32: icmp_seq=4 ttl=64 time=0.230 ms

--- 192.168.122.32 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3099ms
rtt min/avg/max/mdev = 0.230/0.289/0.321/0.036 ms
```

### 3.2. Explication technique

La commande `ping` utilise le protocole ICMP pour vérifier la disponibilité d'une machine sur le réseau.

Les paramètres importants du résultat sont :

- `4 packets transmitted` : quatre paquets ICMP ont été envoyés.
- `4 received` : les quatre paquets ont reçu une réponse.
- `0% packet loss` : aucune perte de paquets n'a été constatée.
- `ttl=64` : valeur du Time To Live (durée de vie du paquet IP).
- `time=0.289 ms` : temps moyen aller-retour des paquets.

Le TTL représente le nombre de sauts réseau autorisés avant qu'un paquet soit supprimé. Il est initialisé par le système émetteur et décrémenté à chaque routeur traversé.

### 3.3. Conclusion

La connectivité IP entre Kgoumou et Proxmox VE est fonctionnelle.

Le serveur Proxmox répond correctement aux requêtes ICMP.

## 4. Vérification de l'accessibilité de l'API HTTPS

Après validation de la connectivité réseau, nous avons vérifié l'accessibilité de l'API REST de Proxmox.

L'API permet aux outils externes, notamment Terraform, d'interagir avec les ressources Proxmox.

### 4.1. Première requête HTTP

Commande exécutée :

```bash
curl -k https://192.168.122.32:8006/api2/json
```

Cette première commande n'a affiché aucun résultat dans le terminal.

Nous avons donc effectué un second test pour identifier précisément le code de réponse HTTP.

### 4.2. Vérification du code HTTP

Commande exécutée :

```bash
curl -k -sS -o /dev/null -w "HTTP Status: %{http_code}\n" https://192.168.122.32:8006/api2/json
```

Résultat obtenu :

```text
HTTP Status: 401
```

### 4.3. Explication technique

Décomposition de la commande :

| Option | Signification |
|---|---|
| `curl` | Outil de transfert de données réseau |
| `-k` | Ignore la validation du certificat TLS |
| `-sS` | Mode silencieux, tout en affichant les erreurs |
| `-o /dev/null` | Ignore le contenu de la réponse |
| `-w` | Permet d'afficher des informations sur la requête |
| `%{http_code}` | Affiche le code de réponse HTTP |

Le code HTTP `401 Unauthorized` signifie que le serveur a reçu la requête, mais qu'aucune authentification valide n'a été fournie.

Dans notre cas, ce résultat est attendu puisque nous n'avons pas encore configuré de compte ou de jeton API pour Terraform.

Il confirme que :

- Le serveur HTTPS Proxmox est accessible.
- La connexion TLS a été établie malgré le certificat autosigné.
- Le point d'accès `/api2/json` répond.
- Une authentification sera nécessaire pour accéder aux ressources protégées.

**Important :** le code 401 ne signifie pas que l'API est indisponible. Il indique que l'authentification est requise.

## 5. Analyse du certificat TLS Proxmox

Nous avons ensuite examiné le certificat présenté par le serveur Proxmox.

### 5.1. Commande exécutée

```bash
openssl s_client -connect 192.168.122.32:8006 -servername 192.168.122.32 </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

Résultat obtenu :

```text
subject=OU = PVE Cluster Node, O = Proxmox Virtual Environment, CN = pve.crg-bank.lan
issuer=CN = Proxmox Virtual Environment, OU = 8e7f8a0b-53d4-4daf-9791-9635ad7f0cf5, O = PVE Cluster Manager CA
notBefore=Nov  2 10:32:51 2026 GMT
notAfter=Nov  1 10:32:51 2028 GMT
```

### 5.2. Explication technique

La commande `openssl s_client` établit une connexion TLS avec le serveur Proxmox afin de récupérer les informations de son certificat.

La commande `openssl x509` permet ensuite d'extraire les informations principales du certificat.

Explication des champs :

**Subject**

```text
CN = pve.crg-bank.lan
```

Le Common Name (CN) correspond au nom déclaré dans le certificat du serveur.

**Issuer**

```text
CN = Proxmox Virtual Environment
OU = ...
O = PVE Cluster Manager CA
```

L'Issuer désigne l'autorité de certification qui a émis le certificat.

Dans notre cas, le certificat est associé à l'autorité de certification interne de Proxmox.

**notBefore**

```text
Nov 2 10:32:51 2026 GMT
```

Date à partir de laquelle le certificat est valide.

**notAfter**

```text
Nov 1 10:32:51 2028 GMT
```

Date d'expiration du certificat.

### 5.3. Particularité : certificat hérité du template Proxmox

Le nom `pve.crg-bank.lan` correspond à l'identité historique de l'ancienne VM Proxmox utilisée comme template.

Lors de la création de la nouvelle VM à partir du disque du template, certains éléments de configuration ont été conservés, notamment l'identité présente dans le certificat TLS.

Nous avons identifié les deux machines suivantes :

| Machine | Adresse IP | Rôle |
|---|---|---|
| Ancienne VM Proxmox | 192.168.122.31 | VM utilisée comme template |
| Nouvelle VM Proxmox | 192.168.122.32 | Serveur cible du projet Terraform |

Sur l'ancienne VM, la commande suivante a confirmé l'association du nom DNS :

```bash
getent hosts pve.crg-bank.lan
```

Résultat :

```text
192.168.122.31 pve.crg-bank.lan pve
```

La nouvelle VM utilise actuellement l'adresse IP `192.168.122.32`, mais son certificat conserve le CN `pve.crg-bank.lan`.

**Conséquence technique :** il faudra tenir compte de cette différence entre l'adresse IP réellement utilisée et le nom présenté dans le certificat lors de la configuration TLS du provider Terraform.

Pour le moment, nous conservons l'adresse IP `192.168.122.32` comme adresse de connexion.

## 6. Identification du serveur Proxmox

Nous avons ensuite vérifié l'identité et les versions des composants du serveur Proxmox.

### 6.1. Vérification du hostname

Commande exécutée sur Proxmox :

```bash
hostname
```

Résultat :

```text
pve
```

Le nom d'hôte actuellement configuré sur la machine est `pve`.

### 6.2. Vérification de la version Proxmox

Commande exécutée :

```bash
pveversion -v
```

Résultat obtenu :

```text
proxmox-ve: 9.2.0 (running kernel: 7.0.14-26-pve)
pve-manager: 9.2.25 (running version: 9.2.25/88a31f5fd94aab6d)
proxmox-kernel-helper: 9.2.1
proxmox-kernel-7.0: 7.0.14-26
proxmox-kernel-7.0.14-26-pve-signed: 7.0.14-26
proxmox-kernel-7.0.2-6-pve-signed: 7.0.2-6
ceph-fuse: 19.2.6-pve4
corosync: 3.1.10-pve3
frr-pythontools: 10.6.1-1+pve3
ifupdown2: 3.3.0-1+pmx12
intel-microcode: 3.20251111.1~deb13u1
ksm-control-daemon: 1.5-1
lvm2: 2.03.31-2+pmx1
pve-cluster: 9.1.8
pve-container: 6.1.16
pve-firewall: 6.0.6
pve-ha-manager: 5.2.5
qemu-server: 9.2.14
zfsutils-linux: 2.4.4-pve1
```

Les autres composants sont également présents dans la sortie complète de la commande.

### 6.3. Explication technique

La commande `pveversion -v` affiche les versions des différents composants installés sur le serveur Proxmox.

Les informations principales sont :

| Composant | Version |
|---|---|
| Proxmox VE | 9.2.0 |
| PVE Manager | 9.2.25 |
| Noyau actif | 7.0.14-26-pve |
| Corosync | 3.1.10-pve3 |
| QEMU Server | 9.2.14 |
| PVE Cluster | 9.1.8 |

Quelques composants importants :

- **PVE Manager** : interface d'administration et gestion des ressources Proxmox.
- **QEMU Server** : gestion des machines virtuelles.
- **Corosync** : communication et coordination entre les nœuds d'un cluster.
- **PVE Cluster** : infrastructure de gestion des configurations et des services du cluster.
- **Noyau PVE** : noyau Linux adapté à l'environnement Proxmox.

Cette vérification permet de confirmer la version exacte de l'environnement cible avant de configurer le provider Terraform.

## 7. Vérification du service pveproxy

Le service `pveproxy` est responsable de l'exposition de l'interface Web et de l'API HTTPS de Proxmox.

### 7.1. Commande exécutée

```bash
systemctl status pveproxy
```

Résultat obtenu :

```text
● pveproxy.service - PVE API Proxy Server
     Loaded: loaded (/usr/lib/systemd/system/pveproxy.service; enabled; preset:>
     Active: active (running) since Tue 2026-11-03 23:34:40 GMT; 10min ago
 Invocation: 40576fda61bf42edaf4d3467ee459d03
    Process: 996 ExecStartPre=/usr/bin/pvecm updatecerts --silent (code=exited,>
    Process: 1003 ExecStart=/usr/bin/pveproxy start (code=exited, status=0/SUCC>
    Main PID: 1006 (pveproxy)
      Tasks: 4 (limit: 5657)
     Memory: 176.2M (peak: 193.3M)
        CPU: 1.159s
```

La sortie complète indique également le démarrage de trois processus workers.

### 7.2. Explication technique

Les informations importantes sont :

**Loaded**

```text
Loaded: loaded
```

Le fichier de configuration systemd du service est correctement chargé.

**Enabled**

```text
enabled
```

Le service est activé pour démarrer automatiquement au démarrage du système.

**Active**

```text
Active: active (running)
```

Le service est actuellement démarré et fonctionne.

**Main PID**

```text
Main PID: 1006
```

Le processus principal du service possède le PID 1006.

**Workers**

```text
pveproxy worker
pveproxy worker
pveproxy worker
```

Les processus workers prennent en charge le traitement des requêtes entrantes.

### 7.3. Conclusion

Le service `pveproxy` est opérationnel et activé au démarrage de Proxmox.

Il constitue le point d'entrée HTTPS utilisé par les clients externes pour communiquer avec l'API Proxmox.

## 8. Vérification de l'écoute sur le port TCP 8006

Après avoir vérifié l'état du service, nous avons contrôlé l'écoute réseau sur le port utilisé par l'API.

### 8.1. Commande exécutée

```bash
ss -lntp | grep 8006
```

Résultat obtenu :

```text
LISTEN 0      4096               *:8006            *:*    users:(("pveproxy worker",pid=1009,fd=6),("pveproxy worker",pid=1008,fd=6),("pveproxy worker",pid=1007,fd=6),("pveproxy",pid=1006,fd=6))
```

### 8.2. Explication technique

La commande `ss` permet d'afficher les sockets réseau du système.

Options utilisées :

| Option | Signification |
|---|---|
| `-l` | Affiche les sockets en écoute |
| `-n` | Affiche les ports sous forme numérique |
| `-t` | Filtre les connexions TCP |
| `-p` | Affiche les processus associés |

Le résultat contient les informations suivantes :

**LISTEN**

Indique que le serveur est en attente de connexions entrantes.

**\*:8006**

Indique que le port TCP 8006 est en écoute sur toutes les interfaces réseau disponibles pour ce socket.

**pveproxy**

Le processus principal et ses workers sont associés à cette écoute.

### 8.3. Conclusion

Le port TCP 8006 est bien ouvert en écoute sur le serveur Proxmox.

Le service `pveproxy` est donc prêt à recevoir les requêtes HTTPS provenant de Kgoumou.

## 9. Bilan des vérifications

Les tests effectués permettent de confirmer la disponibilité du serveur Proxmox et de son API HTTPS.

| Vérification | Résultat |
|---|---|
| Connectivité IP avec ping | Validée |
| Accessibilité HTTPS | Validée |
| Réponse de l'API | HTTP 401 — authentification requise |
| Certificat TLS | Informations récupérées |
| Identification du serveur | Validée |
| Version Proxmox VE | 9.2.0 |
| Service pveproxy | Active (running) |
| Port TCP 8006 | LISTEN |

## 10. Conclusion

La communication réseau entre Kgoumou et Proxmox VE 9.2 est fonctionnelle.

Le serveur Proxmox est accessible sur l'adresse IP `192.168.122.32` et son API HTTPS répond sur le port TCP `8006`.

Le service `pveproxy` est actif et écoute correctement sur ce port.

Le code HTTP 401 obtenu lors du test de l'API confirme que l'authentification sera nécessaire pour accéder aux ressources protégées.

La prochaine étape consistera à préparer un accès dédié à Terraform, avec un utilisateur Proxmox et un API Token disposant des permissions nécessaires.

**Environnement validé pour la suite du projet : Terraform sur Kgoumou → API HTTPS → Proxmox VE 9.2.**