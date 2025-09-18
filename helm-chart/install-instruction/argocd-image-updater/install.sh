# helm repo add argo https://argoproj.github.io/argo-helm

# helm fetch argo/argocd-image-updater

# tar -zxvf argocd-image-updater-0.12.3.tgz

kubectl create namespace argocd

cd helm-chart

helm install --values ./install-instruction/argocd-image-updater/values.yaml argocd ./argo-cd --namespace argocd

helm install argocd-image-updater ./argocd-image-updater --namespace argocd
