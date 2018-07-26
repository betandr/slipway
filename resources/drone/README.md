

helm init --service-account tiller

helm install --name project -f values.yaml stable/drone


helm upgrade project -f values.yaml stable/drone


helm install --name cert-manager --namespace kube-system stable/cert-manager

kubectl apply -f acme-issuer.yaml
