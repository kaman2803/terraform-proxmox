# Section 17 — Préparation de Cloud-Init pour les machines virtuelles

## 1. Objectif

Préparer les paramètres nécessaires à l'initialisation automatique des futures machines virtuelles Ubuntu Server 24.04 LTS sur Proxmox VE avec Terraform et Cloud-Init.

Les objectifs sont :
- Définir le compte Linux qui sera créé sur chaque VM.
- Injecter une clé publique SSH pour permettre l'administration à distance.
- Prévoir une configuration réseau IPv4 en DHCP.
- Identifier le bridge réseau Proxmox auquel les VM seront raccordées.
- Déclarer les paramètres correspondants dans Terraform.

**Important :** cette section prépare les paramètres. Leur intégration effective dans les ressources VM sera réalisée lors de la définition de ces ressources.

## 2. Définition de l'utilisateur Linux

Le compte Linux retenu pour les futures machines virtuelles est :

| Paramètre | Valeur |
|---|---|
| Nom d'utilisateur | `kaman` |
| Système cible | Ubuntu Server 24.04 LTS |
| Méthode d'initialisation | Cloud-Init |

La variable correspondante est déclarée dans `variables.tf` :

```hcl
variable "vm_username" {
  description = "Utilisateur Linux créé par Cloud-Init"
  type        = string
  default     = "kaman"
}
```

## 3. Préparation de la clé publique SSH

### 3.1. Identification des clés disponibles

Commande exécutée sur Kgoumou :

```bash
ls -l ~/.ssh/
```

Le répertoire contenait notamment :
- `id_ed25519` et `id_ed25519.pub`
- `id_ed25519_ansible_zabbix` et sa clé publique
- `id_ed25519_github` et sa clé publique

La clé générale `id_ed25519.pub` a été retenue pour les connexions SSH aux futures VM. Les clés dédiées à GitHub et Ansible ne seront pas utilisées.

### 3.2. Vérification de l'empreinte

```bash
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

Résultat :

```text
256 SHA256:H47yXp2ieJo/IX8zSJa19TKy9in1SSwhrq0PP3IFZak kaman-goumou@Kgoumou (ED25519)
```

### 3.3. Vérification de l'accessibilité

```bash
test -r ~/.ssh/id_ed25519.pub && echo "Clé publique accessible" || echo "Clé publique inaccessible"
```

Résultat :

```text
Clé publique accessible
```

### 3.4. Identification du chemin absolu

```bash
readlink -f ~/.ssh/id_ed25519.pub
```

Résultat :

```text
/home/kaman-goumou/.ssh/id_ed25519.pub
```

### 3.5. Déclaration dans Terraform

La variable suivante a été ajoutée à `variables.tf` :

```hcl
variable "ssh_public_key_path" {
  description = "Chemin de la clé publique SSH utilisée par Cloud-Init"
  type        = string
  default     = "/home/kaman-goumou/.ssh/id_ed25519.pub"
}
```

Cloud-Init pourra ainsi utiliser cette clé publique pour autoriser l'authentification SSH de l'utilisateur `kaman`.

La clé privée reste sur Kgoumou et ne doit pas être copiée dans la configuration Terraform ni sur Proxmox.

## 4. Identification du réseau Proxmox

### 4.1. Vérification des interfaces réseau

Sur Proxmox `pve1` :

```bash
ip -br link
```

Résultat :

```text
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
enp1s0           UP             52:54:00:75:a7:9b <BROADCAST,MULTICAST,UP,LOWER_UP>
vmbr0            UP             52:54:00:75:a7:9b <BROADCAST,MULTICAST,UP,LOWER_UP>
```

Le bridge `vmbr0` est opérationnel et raccordé à l'interface `enp1s0`.

### 4.2. Vérification de l'adresse IP du bridge

```bash
ip -br addr show vmbr0
```

Résultat :

```text
vmbr0            UP             192.168.122.32/24 fe80::5054:ff:fe75:a79b/64
```

L'adresse IPv4 du bridge Proxmox est `192.168.122.32/24`.

### 4.3. Vérification de la configuration réseau Proxmox

```bash
cat /etc/network/interfaces
```

Résultat :

```text
auto lo
iface lo inet loopback

iface enp1s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.122.32/24
    gateway 192.168.122.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0

source /etc/network/interfaces.d/*
```

La configuration confirme :
- `enp1s0` est l'interface physique.
- `vmbr0` est configuré en adresse IP statique.
- L'adresse de Proxmox est `192.168.122.32/24`.
- La passerelle est `192.168.122.1`.

L'adresse statique de Proxmox est conservée. Les futures VM utiliseront leur propre configuration DHCP.

## 5. Vérification des réseaux virtuels libvirt sur Kgoumou

### 5.1. Liste des réseaux

Commande exécutée sur Kgoumou :

```bash
virsh net-list --all
```

Résultat :

```text
 Name      State    Autostart   Persistent
--------------------------------------------
 default   active   yes         yes
 isp2      active   yes         yes
```

Deux réseaux virtuels sont actifs : `default` et `isp2`.

### 5.2. Analyse du réseau default

```bash
virsh net-dumpxml default
```

Résultat :

```xml
<network connections='1'>
  <name>default</name>
  <uuid>01459c45-d56b-4c05-9823-96c02f81c309</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:f3:14:42'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.100' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
```

Caractéristiques du réseau :

| Paramètre | Valeur |
|---|---|
| Réseau libvirt | `default` |
| Mode | NAT |
| Bridge hôte | `virbr0` |
| Passerelle | `192.168.122.1` |
| Sous-réseau | `192.168.122.0/24` |
| Début de plage DHCP | `192.168.122.100` |
| Fin de plage DHCP | `192.168.122.254` |

Ce réseau correspond à celui auquel Proxmox est raccordé.

### 5.3. Analyse du réseau isp2

```bash
virsh net-dumpxml isp2
```

Résultat :

```xml
<network>
  <name>isp2</name>
  <uuid>0328588b-291e-44ed-bb1a-e69845a4a834</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:91:4d:f9'/>
  <ip address='192.168.200.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.200.10' end='192.168.200.200'/>
    </dhcp>
  </ip>
</network>
```

Le réseau `isp2` possède un sous-réseau distinct, `192.168.200.0/24`. Il n'est pas utilisé pour le raccordement actuel de Proxmox.

### 5.4. Choix du réseau

Le réseau `default` est retenu pour le projet.

L'utilisateur a confirmé que le serveur DHCP répond correctement sur le réseau concerné.

La configuration réseau prévue pour les futures VM est donc :
- Bridge Proxmox : `vmbr0`.
- Mode IPv4 : DHCP.
- Réseau : `192.168.122.0/24`.
- Passerelle du réseau : `192.168.122.1`.

## 6. Déclaration du bridge dans Terraform

La variable suivante a été ajoutée à `variables.tf` :

```hcl
variable "vm_bridge" {
  description = "Bridge réseau Proxmox utilisé par les machines virtuelles"
  type        = string
  default     = "vmbr0"
}
```

Cette variable permet de conserver le nom du bridge dans un paramètre modifiable plutôt que de le coder directement dans chaque ressource VM.

## 7. Vérification des variables Cloud-Init

Une vérification interactive a été effectuée avec :

```bash
terraform console
```

Expression :

```hcl
var.vm_username
```

Résultat :

```text
"kaman"
```

Expression :

```hcl
var.ssh_public_key_path
```

Résultat :

```text
"/home/kaman-goumou/.ssh/id_ed25519.pub"
```

Sortie de la console :

```text
exit
```

Les deux variables sont accessibles et renvoient les valeurs attendues.

## 8. Validation de la configuration Terraform

Commande exécutée dans le répertoire du projet :

```bash
terraform validate
```

Résultat :

```text
Success! The configuration is valid.
```

La validation confirme que la configuration Terraform est syntaxiquement correcte.

## 9. Synthèse de la configuration préparée

| Paramètre | Valeur |
|---|---|
| Utilisateur Linux | `kaman` |
| Système d'exploitation | Ubuntu Server 24.04 LTS |
| Clé publique SSH | `/home/kaman-goumou/.ssh/id_ed25519.pub` |
| Authentification prévue | SSH par clé publique |
| Configuration IPv4 | DHCP |
| Bridge Proxmox | `vmbr0` |
| Passerelle | `192.168.122.1` |
| Réseau | `192.168.122.0/24` |

## 10. Conclusion

La préparation des paramètres Cloud-Init est terminée.

Les variables nécessaires sont déclarées dans `variables.tf` :
- `vm_username`
- `ssh_public_key_path`
- `vm_bridge`

Les paramètres réseau ont été identifiés et le bridge `vmbr0` a été retenu.

La commande `terraform validate` confirme que la configuration est valide.

**État de la section 17 : terminée.**

**Étape suivante : Section 18 — Définition de la ressource Terraform pour le déploiement des machines virtuelles Ubuntu sur Proxmox VE.**

Cette prochaine étape intégrera les paramètres Cloud-Init dans la ressource `proxmox_virtual_environment_vm`, conformément à la documentation du fournisseur BPG.