# Add the Helm chart repository for secrets-store-csi-driver

resource "helm_release" "secrets-store-csi-driver" {
  depends_on = [module.eks]
  name       = "secrets-store-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  wait                = false
  version             = "1.5.3"

  values = [
    <<-EOT
    syncSecret:
        enabled: true
    enableSecretRotation: true
    rotationPollInterval: 15s
    EOT
  ]
  
}


# https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

resource "kubectl_manifest" "aws-secret-provider" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: csi-secrets-store-provider-aws
      namespace: kube-system
  YAML

  depends_on = [
    helm_release.secrets-store-csi-driver
  ]
}

resource "kubectl_manifest" "aws-secret-provider-clusterole" {
  yaml_body = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRole
    metadata:
      name: csi-secrets-store-provider-aws-cluster-role
    rules:
      - apiGroups: [""]
        resources: ["serviceaccounts/token"]
        verbs: ["create"]
      - apiGroups: [""]
        resources: ["serviceaccounts"]
        verbs: ["get"]
      - apiGroups: [""]
        resources: ["pods"]
        verbs: ["get"]
      - apiGroups: [""]
        resources: ["nodes"]
        verbs: ["get"]
  YAML

  depends_on = [
    helm_release.secrets-store-csi-driver
  ]
}

resource "kubectl_manifest" "aws-secret-provider-daemonset" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      namespace: kube-system
      name: csi-secrets-store-provider-aws
      labels:
        app: csi-secrets-store-provider-aws
    spec:
      updateStrategy:
        type: RollingUpdate
      selector:
        matchLabels:
          app: csi-secrets-store-provider-aws
      template:
        metadata:
          labels:
            app: csi-secrets-store-provider-aws
        spec:
          serviceAccountName: csi-secrets-store-provider-aws
          hostNetwork: false
          containers:
            - name: provider-aws-installer
              image: public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:2.1.0
              imagePullPolicy: Always
              args:
                - --provider-volume=/var/run/secrets-store-csi-providers
              resources:
                requests:
                  cpu: 50m
                  memory: 100Mi
                limits:
                  cpu: 50m
                  memory: 100Mi
              securityContext:
                privileged: false
                allowPrivilegeEscalation: false
              volumeMounts:
                - mountPath: "/var/run/secrets-store-csi-providers"
                  name: providervol
                - name: mountpoint-dir
                  mountPath: /var/lib/kubelet/pods
                  mountPropagation: HostToContainer
          volumes:
            - name: providervol
              hostPath:
                path: "/var/run/secrets-store-csi-providers"
            - name: mountpoint-dir
              hostPath:
                path: /var/lib/kubelet/pods
                type: DirectoryOrCreate
          nodeSelector:
            kubernetes.io/os: linux
  YAML

  depends_on = [
    helm_release.secrets-store-csi-driver
  ]
}

resource "kubectl_manifest" "aws-secret-provider-clusterolebinding" {
  yaml_body = <<-YAML
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: csi-secrets-store-provider-aws-cluster-rolebinding
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: csi-secrets-store-provider-aws-cluster-role
    subjects:
      - kind: ServiceAccount
        name: csi-secrets-store-provider-aws
        namespace: kube-system
  YAML

  depends_on = [
    helm_release.secrets-store-csi-driver
  ]
}

# Trusted entities
data "aws_iam_policy_document" "secrets_csi_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:*:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"]
      type        = "Federated"
    }
  }
}

# Role
resource "aws_iam_role" "secrets_csi" {
  assume_role_policy = data.aws_iam_policy_document.secrets_csi_assume_role_policy.json
  name               = "${var.project}-${var.environment}-secrets-csi-role"
}

# Policy
resource "aws_iam_policy" "secrets_csi" {
  name = "${var.project}-${var.environment}-secrets-csi-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = ["${aws_secretsmanager_secret.general_secret.arn}"]
    }]
  })
}

resource "aws_secretsmanager_secret" "general_secret" {
  name        = "${var.project}-${var.environment}-general-secret"
  description = "General secret for CSI driver testing"
}

# Policy Attachment
resource "aws_iam_role_policy_attachment" "secrets_csi" {
  policy_arn = aws_iam_policy.secrets_csi.arn
  role       = aws_iam_role.secrets_csi.name
}

# Service Account
resource "kubectl_manifest" "secrets_csi_sa" {
  yaml_body = <<YAML
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: secrets-csi-sa
      namespace: kube-system
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.secrets_csi.arn}
  YAML
  depends_on = [
    aws_iam_role.secrets_csi
  ]
}