module "cluster_control" {
  source = "./cluster"

  name         = "control"
  keypair_name = "timebertt"
}
