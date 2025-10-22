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
  common_tags           = [for k, v in local.common_metadata : "${k}=${v}"]
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
  key_pair  = var.keypair_name != "" ? var.keypair_name : openstack_compute_keypair_v2.keypair_generated[0].name

  block_device {
    source_type      = "volume"
    uuid             = openstack_blockstorage_volume_v3.control_plane.id
    destination_type = "volume"
    boot_index       = 0
  }

  network {
    port = openstack_networking_port_v2.control_plane.id
  }

  user_data = templatefile("${path.module}/user_data.tpl", {
    "role"             = "control-plane"
    "token"            = random_password.k3s_token.result
    "control_plane_ip" = openstack_networking_port_v2.control_plane.all_fixed_ips[0]
    "node_ip"          = openstack_networking_port_v2.control_plane.all_fixed_ips[0]
  })
}

resource "random_password" "k3s_token" {
  length  = 64
  special = false
}
