# Source: https://gist.github.com/87171c3597df248bc940da04b22d551e

#########
# Setup #
#########

# Requirements:
# - Kubernetes cluster (e.g., dok-simple-ingress.sh)
# - NGINX Ingress

# Open https://github.com/vfarcic/couchbase-demo

# Fork it!

# Replace `[...]` with the GitHub organization or the username
export GH_ORG=[...]

git clone https://github.com/$GH_ORG/couchbase-demo.git

cd couchbase-demo

# Replace `[...]` with the base host that should be used to access the app through NGINX Ingress
export BASE_HOST=[...] # e.g., $INGRESS_HOST.xip.io

rm -f production/couchbase-cluster.yaml

cat production/argo-cd.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee production/argo-cd.yaml

cat argo-cd/base/ingress.yaml \
    | sed -e "s@acme.com@argo-cd.$BASE_HOST@g" \
    | tee argo-cd/overlays/production/ingress.yaml

cat production/sealed-secrets.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee production/sealed-secrets.yaml

cat production/argo-cd.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee production/argo-cd.yaml

cat production/couchbase-operator.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee production/couchbase-operator.yaml

cat orig/couchbase-cluster.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee orig/couchbase-cluster.yaml

cat orig/couchbase-cluster-ingress.yaml \
    | sed -e "s@acme.com@couchbase.$BASE_HOST@g" \
    | tee couchbase-cluster/base/ingress.yaml
    
couchbase-cluster/base/ingress.yaml

cat apps.yaml \
    | sed -e "s@vfarcic@$GH_ORG@g" \
    | tee apps.yaml

kubectl apply --filename sealed-secrets

kustomize build \
    argo-cd/overlays/production \
    | kubectl apply --filename -

kubectl --namespace argocd \
    rollout status \
    deployment argocd-server

export PASS=$(kubectl \
    --namespace argocd \
    get secret argocd-initial-admin-secret \
    --output jsonpath="{.data.password}" \
    | base64 --decode)

argocd login \
    --insecure \
    --username admin \
    --password $PASS \
    --grpc-web \
    argo-cd.$BASE_HOST

argocd account update-password \
    --current-password $PASS \
    --new-password admin

echo "apiVersion: v1
kind: Secret
metadata:
  name: couchbase-auth
  namespace: couchbase
type: Opaque
data:
  username: $(echo -n "admin" | base64)
  password: $(echo -n "admin12345678" | base64)" \
    | kubeseal --format yaml \
    | tee couchbase-operator/base/secrets.yaml

git add .

git commit -m "Manifests"

git push

kubectl apply --filename project.yaml

kubectl apply --filename apps.yaml

#############################################
# Deploying Couchbase (and everything else) #
#############################################

open http://argo-cd.$BASE_HOST

cat couchbase-cluster/base/cluster.yaml

cat couchbase-operator/base/secrets.yaml

cat orig/couchbase-cluster.yaml

cp orig/couchbase-cluster.yaml \
    production/.

git add .

git commit -m "Cluster"

git push

kubectl --namespace couchbase \
    get pods

open http://couchbase.$BASE_HOST

# Show the image in the Argo CD UI

cat couchbase-cluster/base/cluster.yaml \
    | sed -e "s@6.5.0@6.6.0@g" \
    | tee couchbase-cluster/base/cluster.yaml

git add .

git commit -m "Upgrade"

git push

# Show the image in the Argo CD UI

cd ../