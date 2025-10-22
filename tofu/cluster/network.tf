data "openstack_networking_network_v2" "ext_network" {
  name = "DHBW"
}

resource "openstack_networking_port_v2" "control_plane" {
  name        = "${local.resource_name}-control-plane"
  description = "Port for control plane node of cluster ${local.cluster_name}"
  tags        = local.common_tags

  network_id = data.openstack_networking_network_v2.ext_network.id
  security_group_ids = [openstack_networking_secgroup_v2.control_plane.id]
}

output "control_plane_external_ip" {
  description = "Control plane address on the external network (from the created port)."
  value       = openstack_networking_port_v2.control_plane.all_fixed_ips[0]
}

resource "openstack_networking_secgroup_v2" "control_plane" {
  name        = local.resource_name
  description = "Security group for control plane node of cluster ${local.cluster_name}"
  tags        = local.common_tags
}

resource "openstack_networking_secgroup_rule_v2" "allow_ssh" {
  description       = "Allow SSH (port 22) from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_self_ingress" {
  description       = "Allow all ingress from instances in the same security group"
  direction         = "ingress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
  remote_group_id   = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_icmp" {
  description       = "Allow ICMP from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_kube_apiserver" {
  description       = "Allow kube-apiserver access from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_http" {
  description       = "Allow HTTP access from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_https" {
  description       = "Allow HTTPS access from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}

resource "openstack_networking_secgroup_rule_v2" "allow_8080" {
  description       = "Allow access to port 8080 from anywhere"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.control_plane.id
}
