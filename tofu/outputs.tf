output "control_kubeconfig" {
  description = "Kubeconfig for the control cluster."
  value       = module.cluster_control.kubeconfig
  sensitive   = true
}

output "control_ssh_private_key" {
  description = "SSH private key for the control cluster."
  value       = module.cluster_control.ssh_private_key
  sensitive   = true
}
