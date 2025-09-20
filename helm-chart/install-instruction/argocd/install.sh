# helm repo add bitnami https://charts.bitnami.com/bitnami


# helm fetch bitnami/argo-cd

# tar -zxvf argo-cd-11.0.0.tgz

kubectl create namespace argocd

cd helm-chart

helm install --values ./install-instruction/argocd/values.yaml argocd ./argo-cd --namespace argocd

argo-ingress.yml

kubectl apply -f ./install-instruction/argocd/ingress.yml
