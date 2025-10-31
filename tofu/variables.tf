variable "image_name" {
  description = "Name or regex for the image to use for the cluster nodes."
  type        = string
  default     = "Ubuntu 24.04.*"
}

variable "image_id" {
  description = "ID of the image to use for the cluster nodes (optional). If set, this takes precedence over image_name."
  type        = string
  default     = ""
}

variable "cluster_count" {
  description = "Number of student clusters to create."
  type        = number
  default     = 1
}
