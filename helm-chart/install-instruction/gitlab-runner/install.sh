# helm repo add gitlab https://charts.gitlab.io/

# helm fetch gitlab/gitlab-runner 

# tar -zxvf gitlab-runner-0.80.1.tgz

kubectl create namespace gitlab-runner 

cd helm-chart

helm install --values ./install-instruction/gitlab-runner/values.yaml gitlab-runner ./gitlab-runner  --namespace gitlab-runner 