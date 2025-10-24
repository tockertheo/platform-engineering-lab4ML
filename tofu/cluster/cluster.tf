resource "random_pet" "cluster_name" {
  length = 2
}

locals {
  cluster_name  = var.name != "" ? var.name : random_pet.cluster_name.id
  resource_name = "cluster-${local.cluster_name}"
  common_metadata = {
    "module"                = "cluster"
    "kubernetes.io/cluster" = local.cluster_name
  }
  common_tags = [for k, v in local.common_metadata : "${k}=${v}"]
  # Some OpenStack resource tag values must not contain ',' or '/'.
  # Sanitize metadata keys by replacing '/' with '_'.
  common_tags_sanitized = [for k, v in local.common_metadata : "${replace(k, "/", "_")}=${v}"]
}

data "openstack_compute_flavor_v2" "control_plane" {
  name = var.control_plane_node.flavor
}

data "openstack_images_image_v2" "image" {
  name_regex  = "^${var.image_name}$"
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "control_plane" {
  name        = "${local.resource_name}-control-plane"
  description = "Boot volume for control plane node of cluster ${local.cluster_name}"
  metadata    = local.common_metadata
  image_id    = data.openstack_images_image_v2.image.id
  size        = 20
}

resource "openstack_compute_instance_v2" "control_plane" {
  name      = "${local.resource_name}-control-plane"
  tags      = local.common_tags_sanitized
  flavor_id = data.openstack_compute_flavor_v2.control_plane.id
  key_pair  = openstack_compute_keypair_v2.keypair.name

  block_device {
    source_type      = "volume"
    uuid             = openstack_blockstorage_volume_v3.control_plane.id
    destination_type = "volume"
    boot_index       = 0
  }

  network {
    port = openstack_networking_port_v2.control_plane.id
  }

  user_data = templatefile("${path.module}/user_data.tftpl", {
    "role"                  = "control-plane"
    "control_plane_ip"      = local.control_plane_ip
    "control_plane_address" = local.control_plane_address
    "node_ip"               = openstack_networking_port_v2.control_plane.all_fixed_ips[0]
    "token"                 = random_password.k3s_token.result
    "ssh_user"              = var.ssh_username
  })
}

resource "terraform_data" "fetch_kubeconfig" {
  triggers_replace = {
    instance_id = openstack_compute_instance_v2.control_plane.id
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /home/${var.ssh_username}/kubeconfig.yaml ]; do echo 'Waiting for k3s installation to finish...' && sleep 10; done"
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_username
      private_key = tls_private_key.ssh_key.private_key_openssh
      host        = local.control_plane_ip
    }
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -i ${local_sensitive_file.ssh_private_key.filename} \
          ${var.ssh_username}@${local.control_plane_ip}:/home/${var.ssh_username}/kubeconfig.yaml \
          ${local.kubeconfig_path}
    EOT
  }
}

resource "random_password" "k3s_token" {
  length  = 64
  special = false
}

locals {
  kubeconfig_path = "${path.root}/secrets/${local.cluster_name}/kubeconfig.yaml"
}

data "local_file" "kubeconfig" {
  filename = local.kubeconfig_path

  depends_on = [terraform_data.fetch_kubeconfig]
}

output "kubeconfig" {
  description = "Kubeconfig for external cluster access."
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}
