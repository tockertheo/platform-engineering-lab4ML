data "openstack_compute_flavor_v2" "control_plane" {
  name = var.control_plane_node.flavor
}

data "openstack_compute_flavor_v2" "worker" {
  name = var.worker_nodes.flavor
}

data "openstack_images_image_v2" "image" {
  name_regex  = "^${var.image_name}$"
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "node" {
  for_each = local.nodes

  name        = each.value.name
  description = "Boot volume for node ${each.value.name}"
  metadata    = local.common_metadata
  image_id    = data.openstack_images_image_v2.image.id
  size        = each.value.volume_size
}

resource "openstack_compute_instance_v2" "node" {
  for_each = local.nodes

  name = each.value.name
  tags = local.common_tags_sanitized
  flavor_id = (each.value.role == "control-plane" ? data.openstack_compute_flavor_v2.control_plane.id :
  data.openstack_compute_flavor_v2.worker.id)
  key_pair = openstack_compute_keypair_v2.keypair.name

  block_device {
    source_type      = "volume"
    uuid             = openstack_blockstorage_volume_v3.node[each.key].id
    destination_type = "volume"
    boot_index       = 0
  }

  network {
    port = openstack_networking_port_v2.node[each.key].id
  }

  user_data = templatefile("${path.module}/user_data.tftpl", {
    "role"                  = each.value.role
    "control_plane_ip"      = local.control_plane_ip
    "control_plane_address" = local.control_plane_address
    "node_ip"               = openstack_networking_port_v2.node[each.key].all_fixed_ips[0]
    "token"                 = random_password.k3s_token.result
    "ssh_user"              = var.ssh_username
  })
}
