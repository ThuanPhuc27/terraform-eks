variable "environment" {
  description = "Environment name"
  type        = string
  default     = "demo"
}

variable "region" {
  description = "region name"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "eks-demo"
}

variable "vpc" {
  description = "VPC configuration"
  type = object({
    cidr                = string
    availability_zones  = list(string)
    private_subnets     = list(string)
    public_subnets      = list(string)
    enable_nat_gateway  = bool
    single_nat_gateway  = bool
    one_nat_gateway_per_az = bool
  })
  default = {
    cidr                = "10.0.0.0/16"
    availability_zones  = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
    private_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets      = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6/24"]
    enable_nat_gateway  = true
    single_nat_gateway  = true
    one_nat_gateway_per_az = false
  }
}
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_caller_identity" "current" {}