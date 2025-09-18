include "root" {
  path = find_in_parent_folders("../root.hcl")
}

terraform {
    source = "../../../modules/vpc-eks"
}

locals {
  environment = "dev"
  project     = "shoeshop"
}

inputs = {
  environment = local.environment
  project     = local.project
  region      = "ap-southeast-1"

  vpc = {
    cidr                   = "10.0.0.0/16"
    availability_zones     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    private_subnets        = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets         = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false
  } 
  eks = {
    cluster_version = "1.33"
  }
}

