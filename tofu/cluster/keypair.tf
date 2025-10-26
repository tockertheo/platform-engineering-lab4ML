resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = local.resource_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.root}/secrets/${local.cluster_name}/ssh-private-key"
  content         = tls_private_key.ssh_key.private_key_openssh
  file_permission = "0600"
}

output "ssh_private_key" {
  description = "SSH private key for external node access."
  value       = tls_private_key.ssh_key.private_key_openssh
  sensitive   = true
}
