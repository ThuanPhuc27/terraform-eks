
resource "helm_release" "metrics-server" {
  depends_on = [module.eks]
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  wait       = false
  version    = "3.12.2"
  values = [
    <<-EOT
    tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
    EOT
  ]
}