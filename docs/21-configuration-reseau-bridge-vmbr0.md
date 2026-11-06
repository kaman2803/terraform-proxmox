# Section 21 — Configuration réseau : bridge Proxmox `vmbr0`

## 1. Objectif

Cette section consiste à configurer la carte réseau virtuelle de la machine Ubuntu Server 24.04 LTS afin de la raccorder au réseau Proxmox.

L'objectif est de permettre à la future machine virtuelle :
- De disposer d'une carte réseau virtuelle.
- D'être raccordée au bridge Proxmox `vmbr0`.
- D'utiliser le modèle de carte réseau VirtIO.
- D'obtenir automatiquement une adresse IPv4 grâce à DHCP, configuré précédemment avec Cloud-Init.

La configuration est réalisée dans le fichier `vm.tf`, sans modifier `variables.tf`.

## 2. Rappel de la variable réseau

La variable `vm_bridge` a été déclarée dans `variables.tf` lors de la section 17 :

```hcl
variable "vm_bridge" {
  description = "Bridge réseau Proxmox utilisé par les machines virtuelles"
  type        = string
  default     = "vmbr0"
}
```

Cette variable permet de définir le bridge auquel les machines virtuelles seront raccordées.

Valeur retenue : `vmbr0`.

## 3. Vérification préalable de l'environnement réseau

Lors des sections précédentes, les vérifications suivantes ont été réalisées sur Proxmox `pve1`.

### 3.1. Identification des interfaces réseau

Commande exécutée :

```bash
ip -br link
```

Résultat :

```text
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
enp1s0           UP             52:54:00:75:a7:9b <BROADCAST,MULTICAST,UP,LOWER_UP>
vmbr0            UP             52:54:00:75:a7:9b <BROADCAST,MULTICAST,UP,LOWER_UP>
```

Le bridge `vmbr0` est opérationnel et associé à l'interface physique `enp1s0`.

### 3.2. Vérification de l'adresse IP

Commande exécutée :

```bash
ip -br addr show vmbr0
```

Résultat :

```text
vmbr0            UP             192.168.122.32/24 fe80::5054:ff:fe75:a79b/64
```

Le bridge Proxmox possède l'adresse IPv4 `192.168.122.32/24`.

La passerelle du réseau est `192.168.122.1`.

## 4. Ajout de la carte réseau dans vm.tf

Le bloc `network_device` a été ajouté à la ressource `proxmox_virtual_environment_vm`.

Commande exécutée :

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("vm.tf")
content = path.read_text()

network = '''  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

'''

marker = '  initialization {\n'

if network.strip() not in content:
    if marker not in content:
        raise SystemExit("Bloc initialization introuvable : fichier non modifié.")
    content = content.replace(marker, network + marker, 1)
    path.write_text(content)
    print("Carte réseau ajoutée.")
else:
    print("Carte réseau déjà présente : aucune modification.")
PY
```

Résultat obtenu :

```text
Carte réseau ajoutée.
```

## 5. Analyse de la configuration réseau

Le bloc ajouté est le suivant :

```hcl
network_device {
  bridge = var.vm_bridge
  model  = "virtio"
}
```

### 5.1. Le bloc network_device

```hcl
network_device {
  ...
}
```

Ce bloc déclare la carte réseau virtuelle de la machine.

### 5.2. Le paramètre bridge

```hcl
bridge = var.vm_bridge
```

Ce paramètre raccorde la carte réseau au bridge Proxmox défini par la variable `vm_bridge`.

Valeur utilisée : `vmbr0`.

L'utilisation d'une variable permet de changer le bridge ultérieurement sans modifier directement la ressource.

### 5.3. Le paramètre model

```hcl
model = "virtio"
```

Ce paramètre définit le modèle de la carte réseau virtuelle.

Le modèle VirtIO est retenu pour fournir une interface réseau paravirtualisée à la machine Ubuntu.

## 6. Configuration DHCP

La configuration DHCP avait déjà été déclarée dans le bloc Cloud-Init de la section 19 :

```hcl
ip_config {
  ipv4 {
    address = "dhcp"
  }
}
```

Il faut distinguer les deux configurations :

- `network_device` raccorde physiquement la carte réseau virtuelle au bridge Proxmox.
- `ip_config` demande à Cloud-Init de configurer automatiquement l'adresse IPv4 par DHCP.

Les deux blocs sont complémentaires.

## 7. Contenu de vm.tf après la section 21

Après l'ajout de la carte réseau, le fichier `vm.tf` contient :

```hcl
resource "proxmox_virtual_environment_vm" "vm" {
  name      = "${var.vm_prefix}01"
  node_name = "pve1"

  cpu {
    cores = var.vm_cores
  }

  memory {
    dedicated = var.vm_memory
  }

  scsi_hardware = "virtio-scsi-pci"

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.vm_disk_size
  }

  network_device {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  initialization {
    user_account {
      username = var.vm_username
      keys     = [trimspace(file(var.ssh_public_key_path))]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
```

## 8. Validation de la configuration

Après l'ajout du bloc réseau, la commande suivante a été exécutée :

```bash
terraform validate
```

Résultat réellement obtenu :

```text
Success! The configuration is valid.
```

Cette validation confirme que Terraform accepte la configuration déclarée.

## 9. Synthèse de la configuration réseau

| Paramètre | Valeur |
|---|---|
| Bloc Terraform | `network_device` |
| Bridge Proxmox | `vmbr0` |
| Variable utilisée | `var.vm_bridge` |
| Modèle de carte | `virtio` |
| Configuration IPv4 | DHCP |
| Bloc DHCP | `initialization.ip_config` |
| Validation Terraform | Réussie |

## 10. Conclusion

La carte réseau virtuelle a été ajoutée à la ressource Terraform dans le fichier `vm.tf`.

La machine virtuelle sera raccordée au bridge Proxmox `vmbr0` avec une carte réseau VirtIO. La configuration Cloud-Init préparée précédemment permettra de demander une adresse IPv4 automatiquement par DHCP.

La commande `terraform validate` a confirmé que la configuration est valide.

**Section 21 : terminée et validée.**

**Étape suivante : Section 22 — Génération dynamique des machines virtuelles (`srv01`, `srv02`, etc.) à partir des variables `vm_count` et `vm_prefix`.**

Aucune machine virtuelle n'a encore été déployée à cette étape.