output "control_kubeconfig" {
  description = "Kubeconfig for the control cluster."
  value       = module.cluster["control"].kubeconfig
  sensitive   = true
}

output "control_ssh_private_key" {
  description = "SSH private key for the control cluster."
  value       = module.cluster["control"].ssh_private_key
  sensitive   = true
}
