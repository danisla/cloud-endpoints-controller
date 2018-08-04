# Cloud Endpoints and IAP Example

This example shows how to use the Cloud Endpoints Controller with IAP and an L7 Ingress Load Balancer.

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/danisla/cloud-endpoints-controller&page=editor&tutorial=examples/iap/README.md)

## Task 0 - Create GKE Cluster

Set the project, replace `YOUR_PROJECT` with your project ID:

```
gcloud config set project YOUR_PROJECT
```

```
VERSION=$(gcloud container get-server-config --zone us-central1-c --format='value(validMasterVersions[0])')
gcloud container clusters create dev --zone=us-central1-c --cluster-version=${VERSION} --scopes=cloud-platform
```

## Task 1 - Deploy Sample App

1. Deploy the sample app:

```
kubectl run nginx --image nginx:latest --port 80
kubectl expose deploy nginx --port 80 --type ClusterIP
```

## Task 2 - Install Helm

1. Install helm

```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

2. Initialize helm

```
kubectl create clusterrolebinding default-admin --clusterrole=cluster-admin --user=$(gcloud config get-value account)
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account=tiller
until ( helm version --tiller-connection-timeout=1 > /dev/null 2>&1 ); do
    echo "Waiting for tiller install...";
    sleep 2;
done;
echo "Helm install complete"
helm repo update
helm version
```

## Task 3 - Install Cloud Endpoints Controller

1. Install bash hepler functions:

```
curl -L https://raw.githubusercontent.com/danisla/kubefunc/master/kubefunc.bash > ~/.kubefunc.bash
source ~/.kubefunc.bash
```

2. Install Cloud Endpoints Controller

```
helm-install-cloud-endpoints-controller
```

## Task 4 - Generate self-signed certificate with cert-manager

1. Install the cert-manager chart and clusterissuer using the bash helper:

```
helm-install-cert-manager
```

3. Generate CA key and cert:

```
PROJECT=$(gcloud config get-value project)
COMMON_NAME="iap-tutorial.endpoints.${PROJECT}.cloud.goog"

openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=${COMMON_NAME}" -days 3650 -reqexts v3_req -extensions v3_ca -out ca.crt

kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key
```

2. Install the CA issuer:

```
cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
EOF
```

3. Create the certificate:

```
PROJECT=$(gcloud config get-value project)
COMMON_NAME="iap-tutorial.endpoints.${PROJECT}.cloud.goog"

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: iap-tutorial-ingress
spec:
  secretName: iap-tutorial-ingress-tls
  issuerRef:
    name: ca-issuer
    # We can reference ClusterIssuers by changing the kind here.
    # The default value is Issuer (i.e. a locally namespaced Issuer)
    kind: Issuer
  commonName: ${COMMON_NAME}
  dnsNames:
  - ${COMMON_NAME}
EOF
```

4. Wait for the certificate:

```
(until kubectl get secret iap-tutorial-ingress-tls 2>/dev/null; do echo "Waiting for certificate..." ; sleep 2; done)
```

## Task 5 - Generate OAuth Client Credentials

1. Set up your OAuth consent screen:

    a. [Configure the consent screen](https://console.cloud.google.com/apis/credentials/consent)
  
    b. Under Email address, select the address that you want to display as a public contact. You must use either your email address or a Google Group that you own.
  
    c. In the Product name box, enter IAP Tutorial.
  
    d. Click Save.

2. Click Create credentials, and then click OAuth client ID.

3. Under Application type, select Web application. In the Name box, enter IAP Tutorial, and in the Authorized redirect URIs box, enter `https://iap-tutorial.endpoints.PROJECT_ID.cloud.goog/_gcp_gatekeeper/authenticate`, replacing `PROJECT_ID` with the ID of your project. 

4. After you enter the details, click Create. Make note of the client ID and client secret that appear in the OAuth client window.
5. In Cloud Shell, create a Kubernetes secret with your OAuth credentials:

```
CLIENT_ID=YOUR_CLIENT_ID
CLIENT_SECRET=YOUR_CLIENT_SECRET
```

```
kubectl create secret generic iap-oauth --from-literal=client_id=${CLIENT_ID} --from-literal=client_secret=${CLIENT_SECRET}
```

## Task 6 - Deploy iap-ingress chart

1. Create values file for chart:

```
cat > values.yaml <<EOF
projectID: $(gcloud config get-value project)
endpointServiceName: iap-tutorial
targetServiceName: nginx
oauthSecretName: iap-oauth
tlsSecretName: iap-tutorial-ingress-tls
EOF
```

2. Deploy chart to create IAP aware ingress resource:

```
helm install --name iap-tutorial-ingress charts/iap-ingress -f values.yaml
```

3. Wait for the load balancer to be provisioned:

```
PROJECT=$(gcloud config get-value project)
COMMON_NAME="iap-tutorial.endpoints.${PROJECT}.cloud.goog"

(until [[ $(curl -sfk -w "%{http_code}" https://${COMMON_NAME}) == "302" ]]; do echo "Waiting for LB with IAP..."; sleep 2; done)
```

> NOTE: It may take 10-15 minutes for the load balancer to be provisioned.

## Task 7 - Add authorized users

1. Grant your account user access to IAP:

```
USER_EMAIL=$(gcloud config get-value account)
PROJECT=$(gcloud config get-value project)

gcloud projects add-iam-policy-binding ${PROJECT} \
  --role roles/iap.httpsResourceAccessor \
  --member user:${USER_EMAIL}
```

> Repeat step to authorize additional users.

## Task 8 - Cleanup

1. Delete the chart:

```
helm delete --purge iap-tutorial-ingress
```

> This will trigger the load balancer cleanup. Wait a few moments before continuing.

2. Delete the GKE cluster:

```
gcloud container clusters delete dev --zone us-central1-c
```
