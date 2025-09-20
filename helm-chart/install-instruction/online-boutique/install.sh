cd helm-chart

kubectl create namespace online-boutique

helm install --values ./install-instruction/online-boutique/adservice-values.yaml adservice ./helm-general --namespace online-boutique