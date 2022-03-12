terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider libvirt {
  uri = "qemu:///system"
}

locals {
  # kube_version = "1.23.3"
  # masternodes = 1
  # workernodes = 0
  subnet_node_prefix = "10.10.1"
}

resource libvirt_pool local {
  name = "ubuntu"
  type = "dir"
  path = "${path.cwd}/volume_pool"
}

resource libvirt_volume ubuntu2004_cloud {
  name   = "ubuntu20.04.qcow2"
  pool   = libvirt_pool.local.name
  source = "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource libvirt_volume ubuntu2004_resized {
  name           = "ubuntu-volume"
  base_volume_id = libvirt_volume.ubuntu2004_cloud.id
  pool           = libvirt_pool.local.name
  size           = 4 * 1024 * 1024 * 1024 # 40GB
}

data template_file public_key {
  template = file("${path.module}/../.local/.ssh/id_rsa.pub")
}

# data template_file envvars {
#   template = file("${path.module}/envvars.tmpl")
#   vars = {
#     kube_version = local.kube_version
#   }
# }

# resource local_file envvars {
#   content  = data.template_file.envvars.rendered
#   filename = "${path.module}/envvars.env"
# }

data template_file node_user_data {
  template = file("${path.module}/../cloud_init.cfg")
  vars = {
    public_key = data.template_file.public_key.rendered
    hostname = "sample_node"
  }
}

# data template_file master_user_data {
#   count = local.masternodes
#   template = file("${path.module}/../cloud_init.cfg")
#   vars = {
#     public_key = data.template_file.public_key.rendered
#     hostname = "k8s-master-${count.index + 1}"
#     kube_version = local.kube_version
#   }
# }

# data template_file worker_user_data {
#   count = local.workernodes
#   template = file("${path.module}/../cloud_init.cfg")
#   vars = {
#     public_key = data.template_file.public_key.rendered
#     hostname = "k8s-worker-${count.index + 1}"
#     kube_version = local.kube_version
#   }
# }

resource libvirt_cloudinit_disk sample_node {
  name = "cloudinit_master_resized.iso"
  pool = libvirt_pool.local.name
  user_data = data.template_file.node_user_data.rendered
}

# resource libvirt_cloudinit_disk workernodes {
#   count = local.workernodes
#   name = "cloudinit_worker_resized_${count.index}.iso"
#   pool = libvirt_pool.local.name
#   user_data = data.template_file.worker_user_data[count.index].rendered
# }

resource libvirt_network node_network {
  name      = "sample_nodes"
  mode      = "nat"
  domain    = "node.local"
  autostart = true
  addresses = ["${local.subnet_node_prefix}.0/24"]
  dns {
    enabled = true
  }
}

# resource libvirt_network kube_ext_network {
#   name      = "kube_ext"
#   mode      = "nat"
#   bridge    = "vbr1ext"
#   domain    = "ext.k8s.local"
#   autostart = true
#   addresses = ["${local.subnet_ext_prefix}.0/24"]
#   # dns {
#   #   enabled = false
#   # }
#   dhcp {
#     enabled = true
#   }
# }

resource libvirt_domain sample_node {
  name   = "sample_node"
  memory = "2048"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.sample_node.id

  network_interface {
    network_id     = libvirt_network.node_network.id
    hostname       = "sample_node"
    addresses      = ["${local.subnet_node_prefix}.10"]
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.ubuntu2004_resized.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# resource libvirt_domain k8s_workers {
#   count = local.workernodes
#   name   = "k8s-worker-${count.index + 1}"
#   memory = "2048"
#   vcpu   = 2

#   cloudinit = libvirt_cloudinit_disk.workernodes[count.index].id

#   network_interface {
#     network_id     = libvirt_network.kube_node_network.id
#     hostname       = "k8s-worker-${count.index + 1}"
#     addresses      = ["${local.subnet_node_prefix}.2${count.index + 1}"]
#     wait_for_lease = true
#   }

#   disk {
#     volume_id = libvirt_volume.ubuntu2004_resized[local.masternodes+count.index].id
#   }

#   console {
#     type        = "pty"
#     target_type = "serial"
#     target_port = "0"
#   }

#   graphics {
#     type        = "spice"
#     listen_type = "address"
#     autoport    = true
#   }
# }
