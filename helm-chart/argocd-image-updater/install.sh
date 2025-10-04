# helm repo add argo https://argoproj.github.io/argo-helm

# helm fetch argo/argocd-image-updater

# tar -zxvf argocd-image-updater-0.12.3.tgz

kubectl create namespace argocd

cd helm-chart

helm install --values ./install-instruction/argocd-image-updater/values.yaml argocd ./argo-cd --namespace argocd

helm install argocd-image-updater ./argocd-image-updater --namespace argocd

ECRAccessRole

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::043902793725:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/BE682447DC01C40949C58D978B7E5C86"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.ap-southeast-1.amazonaws.com/id/BE682447DC01C40949C58D978B7E5C86:sub": "system:serviceaccount:argocd:argocd-image-updater"
                }
            }
        }
    ]
}