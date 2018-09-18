# Cloud Endpoints Operator Nginx Ingress Example

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/danisla/cloud-endpoints-controller&page=editor&tutorial=examples/nginx-ingress/README.md)

This example shows how to use the cloud-endpoints-operator with nginx-ingress.

## Task 0 - Setup environment

1. Set the project, replace `YOUR_PROJECT` with your project ID:

```
gcloud config set project YOUR_PROJECT
```

2. Install kubectl plugins:

```
mkdir -p ~/.kube/plugins
git clone https://github.com/danisla/kubefunc.git ~/.kube/plugins/kubefunc
```

3. Enable the Service Management API:

```
gcloud services enable servicemanagement.googleapis.com
```

4. Create GKE cluster:

```
VERSION=$(gcloud container get-server-config --zone us-central1-c --format='value(validMasterVersions[0])')
gcloud container clusters create dev --zone=us-central1-c --cluster-version=${VERSION} --scopes=cloud-platform
```

4. Change to the example directory:

```
[[ `basename $PWD` != nginx-ingress ]] && cd examples/nginx-ingress
```

## Task 1 - Install Cloud Endpoints Controller

1. Install helm

```
kubectl plugin install-helm
```

2. Install Cloud Endpoints Controller

```
kubectl plugin install-cloud-endpoints-controller
```

## Task 3 - Install nginx-ingress Controller

1. Install the nginx-ingress controller configured to publish the Service LoadBalacner IP:

```
helm install --name nginx-ingress stable/nginx-ingress \
  --set controller.publishService.enabled=true
```

> Note that the `publishService.enabled` value is required so that the external IP of the Ingress matches the LoadBalancer IP of the nginx-ingress Service. Otherwise, the Ingress would get the IP of the node in the cluster where the controller is running and the cloud-endpoints-operator would pick the wrong IP.

## Task 2 - Deploy Hello App

1. Deploy the hello app:

```
kubectl run hello-app --image=gcr.io/google-samples/hello-app:1.0 --port=8080
```

2. Expose the hello app Deployment as a cluster service:

```
kubectl expose deployment hello-app
```

3. Create Ingress resource for hello app:

```
cat - << EOF| kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-app
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /hello
        backend:
          serviceName: hello-app
          servicePort: 8080
EOF
```

## Task 3 - Create CloudEndpoint resource

1. Create CloudEndpoint resource bound to the hello-app ingress:

```
PROJECT=$(gcloud config get-value project)
INGRESS_NAME=hello-app

cat - <<EOF | kubectl apply -f -
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: hello-app
spec:
  project: ${PROJECT}
  targetIngress:
    name: ${INGRESS_NAME}
    namespace: default
EOF
```

2. Verify endpoint creation:

```
PROJECT=$(gcloud config get-value project)

curl http://hello-app.endpoints.${PROJECT}.cloud.goog/hello
```

> You will see the output of the hello-app once the DNS record has propagated.

## Task 4 - Cleanup

1. Delete the hello-app resources:

```
kubectl delete cloudep,ingress,deploy,service hello-app
```

2. Delete the GKE cluster:

```
gcloud container clusters delete dev --zone us-central1-c
```
