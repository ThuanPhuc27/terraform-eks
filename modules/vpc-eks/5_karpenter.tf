module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.36.1"
  cluster_name = module.eks.cluster_name

  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.6.0"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    EOT
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: spot-pool
    spec:
      disruption:
        budgets:
        - nodes: "1"
        consolidateAfter: 2m
        consolidationPolicy: WhenEmptyOrUnderutilized
      template:
        metadata:
          labels:
            type: karpenter
        spec:
          expireAfter: 720h
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: spot-nodeclass
          requirements:
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
          - key: karpenter.sh/capacity-type
            operator: In
            values: ["spot", "on-demand"]
          - key: node.kubernetes.io/instance-type
            operator: In
            values: ["t3.medium"]
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: spot-nodeclass
    spec:
      amiFamily: AL2023
      amiSelectorTerms:
        - id: ami-0ebf74f8ba7318d44
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 30Gi
            volumeType: gp3
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2
        httpTokens: required
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      userData: |
        #!/bin/bash
        dnf install -y docker
        systemctl enable docker
        systemctl start docker

  YAML

  depends_on = [
    helm_release.karpenter
  ]
}
