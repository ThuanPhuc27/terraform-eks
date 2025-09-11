terraform {
  backend "s3" {
    bucket       = "terraform-state-shoeshop-03092025"  # change to your project name ${var.project}
    key          = "demo/main.tfstate" # change to your environment name ${var.environment}
    region       = "ap-southeast-1"
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
  }
}