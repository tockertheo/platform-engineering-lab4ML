# Generate an SSH keypair when the user didn't provide an existing keypair name.
resource "tls_private_key" "ssh_key_generated" {
  count     = var.keypair_name == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "openstack_compute_keypair_v2" "keypair_generated" {
  count      = var.keypair_name == "" ? 1 : 0
  name       = local.resource_name
  public_key = tls_private_key.ssh_key_generated[0].public_key_openssh
}

resource "local_sensitive_file" "ssh_private_key_generated" {
  filename = "${path.root}/secrets/${local.cluster_name}/ssh-private-key"
  content  = tls_private_key.ssh_key_generated[0].private_key_openssh
}

output "ssh_private_key_generated" {
  description = "SSH private key for the generated keypair. Only set if no keypair_name was provided."
  value       = length(tls_private_key.ssh_key_generated) > 0 ? tls_private_key.ssh_key_generated[0].private_key_openssh : null
  sensitive   = true
}
