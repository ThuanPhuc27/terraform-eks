resource "aws_iam_role" "eks-alb-ingress-controller" {
  name = "eks-alb-ingress-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role_policy.json  
}

# Define the IAM policy document for the AssumeRole policy
data "aws_iam_policy_document" "alb_controller_assume_role_policy" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}



# Add the Helm chart repository for AWS Load Balancer Controller

resource "helm_release" "aws_load_balancer_controller" {
  depends_on = [module.eks]
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  wait                = false

  values = [
    <<-EOT
    clusterName: ${module.eks.cluster_name}
    region: "${var.region}"
    serviceAccount:
      create: true
      name: aws-load-balancer-controller
      annotations:
        eks.amazonaws.com/role-arn: "${aws_iam_role.eks-alb-ingress-controller.arn}"
    tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
    EOT
  ]
  
}