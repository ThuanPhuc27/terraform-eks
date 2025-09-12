// This addon will also create a kubernetes service account with the necessary IAM role attached to managed EBS volumes
resource "aws_eks_addon" "ebs" {
  depends_on = [ module.eks ]
  cluster_name = module.eks.cluster_name 
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.eks-ebs.arn
}

resource "aws_iam_role" "eks-ebs" {
  name = "eks-ebs-${var.project}-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ebs_controller_assume_role_policy.json  
}

resource "aws_iam_role_policy_attachment" "ebs_controller_policy_attachment" {
  role       = aws_iam_role.eks-ebs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Define the IAM policy document for the AssumeRole policy
data "aws_iam_policy_document" "ebs_controller_assume_role_policy" {
  statement {
    actions   = ["sts:AssumeRoleWithWebIdentity"]
    effect    = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}