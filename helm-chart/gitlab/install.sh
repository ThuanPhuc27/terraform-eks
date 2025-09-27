# helm repo add gitlab https://charts.gitlab.io/

# helm fetch gitlab/gitlab 

# tar -zxvf gitlab-9.3.2.tgz

kubectl create namespace gitlab

cd helm-chart

helm install --values ./install-instruction/gitlab/values.yaml gitlab ./gitlab --namespace gitlab