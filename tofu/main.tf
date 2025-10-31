locals {
  student_clusters = {
    for i in range(1, var.cluster_count+1) :
    format("student-%02d", i) => {
      name          = ""
      output_prefix = format("%02d-", i)
    }
  }

  clusters = merge(
    {
      "control" = {
        name          = "control"
        output_prefix = "00-"
      }
    },
    local.student_clusters
  )
}

module "cluster" {
  source = "./cluster"

  for_each = local.clusters

  name          = each.value.name
  output_prefix = each.value.output_prefix

  image_name = var.image_name
  image_id   = var.image_id
}
