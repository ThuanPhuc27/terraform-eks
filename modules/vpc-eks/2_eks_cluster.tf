module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = "${var.project}-${var.environment}"
  cluster_version = "${var.eks.cluster_version}"

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    addons = {
      name                     = "${var.project}-${var.environment}-addon"
      use_name_prefix          = false
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m7i-flex.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      iam_role_additional_policies = {
        "ssm" : "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      }

      taints = {
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }
    }
  }
  
  node_security_group_tags = {
    "karpenter.sh/discovery" = "${var.project}-${var.environment}"
  }
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

}

