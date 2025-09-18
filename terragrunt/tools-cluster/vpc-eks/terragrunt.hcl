include "root" {
  path = find_in_parent_folders("../root.hcl")
}

terraform {
    source = "../../../modules/vpc-eks"
}

locals {
  environment = "dev"
  project     = "tool-cluster"
}

inputs = {
  environment = local.environment
  project     = local.project
  region      = "ap-southeast-1"

  vpc = {
    cidr                   = "10.1.0.0/16"
    availability_zones     = ["ap-southeast-1a", "ap-southeast-1b"]
    private_subnets        = ["10.1.1.0/24", "10.1.2.0/24"]
    public_subnets         = ["10.1.4.0/24", "10.1.5.0/24"]
    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false
  }

  eks = {
    cluster_version = "1.33"
  }
}