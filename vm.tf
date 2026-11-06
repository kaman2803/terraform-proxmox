resource "proxmox_virtual_environment_vm" "vm" {
  count     = var.vm_count
  name      = format("%s%02d", var.vm_prefix, count.index + 1)
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

      import_from = "local:import/ubuntu-24.04-server-cloudimg-amd64.qcow2"
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
