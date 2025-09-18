helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm search repo metrics-server
helm pull metrics-server/metrics-server --version 3.12.2
tar -xzf metrics-server-3.12.2.tgz
helm install metrics-server metrics-server -n kube-system
