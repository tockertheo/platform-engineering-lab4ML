resource "random_string" "cluster_id" {
  count = var.cluster_count

  length  = 4
  lower   = true
  upper   = false
  numeric = false
  special = false
}

locals {
  student_clusters = {
    for i in range(var.cluster_count) :
    format("student-%02d", i + 1) => {
      name          = format("student-%s", random_string.cluster_id[i].id)
      output_prefix = format("%02d-", i + 1)
    }
  }

  clusters = merge(
    {
      "timebertt" = {
        name          = "timebertt"
        output_prefix = "00-"
      }
      "marius" = {
        name          = "marius"
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

resource "pwpush_push" "cluster_credentials" {
  for_each = local.student_clusters

  name = "Kubeconfig and SSH private key for cluster ${each.value.name} (${each.key})"

  kind    = "text"
  payload = <<-EOT
    #!/usr/bin/env bash

    # This script contains the kubeconfig and SSH private key for accessing
    # the cluster ${each.value.name} (${each.key}).

    # Running the script saves the kubeconfig and SSH private key to files
    # in the current working directory.
    # Alternatively, you can copy the contents of the files from below
    # and save them manually to an appropriately named file.
    # After saving the files, set the KUBECONFIG environment variable to
    # point to the kubeconfig file to interact with the cluster using kubectl.

    cat > kubeconfig-${each.value.name}.yaml <<EOF
    ${module.cluster[each.key].kubeconfig}EOF

    cat > ssh-private-key-${each.value.name} <<EOF
    ${module.cluster[each.key].ssh_private_key}EOF
    chmod 600 ssh-private-key-${each.value.name}
  EOT

  expire_after_views = 1
  expire_after_days  = 90
}

resource "local_sensitive_file" "cluster_credentials_links" {
  filename = "${path.root}/secrets/cluster-credentials-links.html"

  content = join("\n", concat(["<ul>"],
    [for key, value in local.student_clusters :
      "<li>${key}: <a href='${pwpush_push.cluster_credentials[key].html_url}' target='_blank'>cluster ${value.name} credentials</a></li>"
    ],
    ["</ul>"],
  ))
}
