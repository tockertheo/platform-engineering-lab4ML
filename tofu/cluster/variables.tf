variable "name" {
  description = "Name of the cluster (optional). If not provided, a random name will be generated. Always prefixed with \"cluster-\"."
  type        = string
  default     = ""
}

variable "keypair_name" {
  description = "Existing keypair name to use for instances (optional). If empty, the module generates a keypair and creates a new keypair with the public key."
  type        = string
  default     = ""
}

variable "image_name" {
  description = "Name or regex for the image to use for the cluster nodes."
  type        = string
  default     = "Ubuntu 24.04.*"
}

variable "control_plane_node" {
  description = "Control plane node to assign to the cluster."
  type = object({
    flavor = string
  })
  default = {
    flavor = "gp1.medium"
  }
}
