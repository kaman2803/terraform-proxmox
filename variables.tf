
variable "vm_count" {
  description = "Nombre de machines virtuelles à déployer"
  type        = number
  default     = 2

  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10 && floor(var.vm_count) == var.vm_count
    error_message = "Le nombre de VM doit être un entier compris entre 1 et 10."
  }
}

variable "vm_prefix" {
  description = "Préfixe des noms des machines virtuelles"
  type        = string
  default     = "srv"
}

variable "vm_cores" {
  description = "Nombre de vCPU par machine virtuelle"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Mémoire RAM par machine virtuelle en Mio"
  type        = number
  default     = 1024
}

variable "vm_disk_size" {
  description = "Taille du disque par machine virtuelle en Gio"
  type        = number
  default     = 15
}

variable "vm_username" {
  description = "Utilisateur Linux créé par Cloud-Init"
  type        = string
  default     = "kaman"
}

variable "ssh_public_key_path" {
  description = "Chemin de la clé publique SSH utilisée par Cloud-Init"
  type        = string
  default     = "/home/kaman-goumou/.ssh/id_ed25519.pub"
}

variable "vm_bridge" {
  description = "Bridge réseau Proxmox utilisé par les machines virtuelles"
  type        = string
  default     = "vmbr0"
}
