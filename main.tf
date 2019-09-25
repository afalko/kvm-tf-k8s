provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "vm-pool" {
  name = "vm-pool"
  type = "dir"
  path = "/os/vm-pool"
}

resource "libvirt_volume" "fedora-base" {
  name   = "fedora-base"
  source = "/os/k8s/Fedora-Cloud-Base-30-1.2.x86_64.qed"
  format = "qed"
  pool   = libvirt_pool.vm-pool.name
}

resource "libvirt_volume" "fedora-vol" {
  count          = 4
  name           = "fedora-${count.index}"
  base_volume_id = libvirt_volume.fedora-base.id
  pool           = libvirt_pool.vm-pool.name
}

resource "libvirt_volume" "empty-vol" {
  count          = 4
  name           = "empty-${count.index}"
  pool           = libvirt_pool.vm-pool.name
  format         = "qed"
}

data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
  pool      = libvirt_pool.vm-pool.name

}

resource "libvirt_domain" "kube-master" {
  count       = 1
  name        = "kube_master"
  fw_cfg_name = "fedora29"
  # TODO: Hack: this let's us know we are master and should run master steps
  vcpu    = 2
  memory = "4096"

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  disk {
    volume_id = libvirt_volume.fedora-vol[count.index].id
  }

  disk {
    volume_id = libvirt_volume.empty-vol[count.index].id
  }

  network_interface {
    network_name = "default"
  }
}

resource "libvirt_domain" "kubelet" {
  count       = 3
  name        = "kubelet-${count.index}"
  fw_cfg_name = "fedora29"
  vcpu         = 1
  memory      = "4096"

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  disk {
    volume_id = libvirt_volume.fedora-vol[count.index + length(libvirt_domain.kube-master)].id
  }

  disk {
    volume_id = libvirt_volume.empty-vol[count.index + length(libvirt_domain.kube-master)].id
  }

  network_interface {
    network_name = "default"
  }
}

