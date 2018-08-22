# Cloud Endpoints Controller

This is not an official Google product.

## Intro

Implementation of a [CompositeController metacontroller](https://github.com/GoogleCloudPlatform/metacontroller) to create and manage Cloud Endpoints services.

This controller utilizes the following major components:
- [Custom Resource Definitions (CRD)](https://kubernetes.io/docs/concepts/api-extension/custom-resources/): Used to represent the new `CloudEndpoint` custom resource.
- [metacontroller](https://github.com/GoogleCloudPlatform/metacontroller): Implements the CompositeController interface for the Custom Resource Definition.

## Prerequisites

1. Create GKE cluster:

```
ZONE=us-central1-b
CLUSTER_VERSION=$(gcloud beta container get-server-config --zone ${ZONE} --format='value(validMasterVersions[0])')

gcloud container clusters create dev \
  --cluster-version ${CLUSTER_VERSION} \
  --machine-type n1-standard-4 \
  --num-nodes 3 \
  --scopes=cloud-platform \
  --zone ${ZONE}
```

2. Install Helm:

```sh
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

3. Initialize Helm

```sh
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account=tiller
```

4. Install metacontroller:

```sh
helm install --name metacontroller --namespace metacontroller charts/metacontroller
```

## Installing the chart

1. Install this chart:

```
helm install --name cloud-endpoints-controller --namespace=metacontroller charts/cloud-endpoints-controller
```

## IAP Ingress Tutorial

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/danisla/cloud-endpoints-controller&page=shell&tutorial=examples/iap-esp/README.md)

Tutorial showing how to use the Cloud Endpoints Controller with the Identity Aware Proxy on Google Kubernetes Engine.

## Examples

### Simple IP target

```sh
PROJECT=$(gcloud config get-value project)
IP_ADDRESS=1.2.3.4

cat > target-ip-cloudep.yaml <<EOF
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: target-ip
spec:
  project: ${PROJECT}
  target: ${IP_ADDRESS}
EOF

kubectl apply -f target-ip-cloudep.yaml
```

Example kubectl commands:

```sh
kubectl get cloudep

kubectl describe cloudep target-ip

kubectl delete cloudep target-ip
```

### Bind to Ingress

```sh
PROJECT=$(gcloud config get-value project)
INGRESS_NAME=nginx-ingress

cat > ingress-cloudep.yaml <<EOF
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: ingress
spec:
  project: ${PROJECT}
  targetIngress:
    name: ${INGRESS_NAME}
    namespace: default
    jwtServices:
    - service3
EOF

kubectl apply -f ingress-cloudep.yaml
```

> The Cloud Endpoint service will be kept in sync with the ingress. If the ingress external IP or backend service changes, a new version of the Endpoint service will be rolled out.

> The `targetIngress.jwtServices` array specifies services in the ingress that will be monitored to populate the `x-google-audiences` field in the OpenAPI spec.

### Full OpenAPI Spec

1. Create a CloudEndpoint resource like one of the examples below:

#### Full OpenAPI Spec

```sh
PROJECT=$(gcloud config get-value project)
TARGET_IP=1.2.3.4

cat > service1-cloudep.yaml <<EOF
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: service1
spec: |-
  openAPISpec:
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "General HTTP Service."
      version: "1.0.0"
    basePath: "/"
    consumes:
    - "application/json"
    produces:
    - "application/json"
    schemes:
    - "https"
    paths:
      "/**":
        get:
          operationId: Get
          responses:
            '200':
              description: Get
            default:
              description: Error
        delete:
          operationId: Delete
          responses:
            '204':
              description: Delete
            default:
              description: Error
        patch:
          operationId: Patch
          responses:
            '200':
              description: Patch
            default:
              description: Error
        post:
          operationId: Post
          responses:
            '200':
              description: Post
            default:
              description: Error
        put:
          operationId: Put
          responses:
            '200':
              description: Put
            default:
              description: Error
    security:
    - google_jwt: []
    securityDefinitions:
      google_jwt:
        authorizationUrl: ""
        flow: "implicit"
        type: "oauth2"
        x-google-issuer: "https://cloud.google.com/iap"
        x-google-jwks_uri: "https://www.gstatic.com/iap/verify/public_key-jwk"
        x-google-audiences: ""

    host: "service1.endpoints.${PROJECT}.cloud.goog"
    x-google-endpoints:
    - name: "service1.endpoints.${PROJECT}.cloud.goog"
      target: "${TARGET_IP}"
EOF

kubectl apply -f service1-cloudep.yaml
```

#### Template OpenAPI Spec and Ingress:  

The `spec.openAPISpec` field is a go template with the following substitutions:

 - `{{.Target}}`: The external IP of the ingress resource when `spec.targetIngress` is specified.
 - `{{.Endpoint}}`: The endpoint URL in the form of: `[NAME].endpoints.[PROJECT].cloud.goog`.
 - `{{.JWTAudiences}}`: Comma-separated list of JWT audiences created from the backend services when `spec.targetIngress.jwtServices[]` is provided. Useful when using Cloud Endpoints with IAP.

```sh
PROJECT=$(gcloud config get-value project)
cat > service4-cloudep-ing.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: service4-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - host: service4.endpoints.${PROJECT}.cloud.goog
    http:
      paths:
      - path:
        backend:
          serviceName: service4
          servicePort: 80
--- 
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: service4
spec:
  project: ${PROJECT}
  targetIngress:
    name: service4-ingress
    namespace: default
    jwtServices:
    - service4
  openAPISpec: |-
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "Test Template Spec: service4"
      version: "1.0.0"
    basePath: "/"
    consumes:
    - "application/json"
    produces:
    - "application/json"
    schemes:
    - "http"
    - "https"
    paths:
      "/**":
        get:
          operationId: Get
          responses:
            '200':
              description: Get
            default:
              description: Error
        delete:
          operationId: Delete
          responses:
            '204':
              description: Delete
            default:
              description: Error
        patch:
          operationId: Patch
          responses:
            '200':
              description: Patch
            default:
              description: Error
        post:
          operationId: Post
          responses:
            '200':
              description: Post
            default:
              description: Error
        put:
          operationId: Put
          responses:
            '200':
              description: Put
            default:
              description: Error
    {{- if .JWTAudiences }}
    security:
    - google_jwt: []
    securityDefinitions:
      google_jwt:
        authorizationUrl: ""
        flow: "implicit"
        type: "oauth2"
        x-google-issuer: "https://cloud.google.com/iap"
        x-google-jwks_uri: "https://www.gstatic.com/iap/verify/public_key-jwk"
        x-google-audiences: "{{ StringsJoin .JWTAudiences "," }}}"
     {{ end }}
    host: "{{.Endpoint}}"
    x-google-endpoints:
    - name: "{{.Endpoint}}"
      target: "{{.Target}}"
EOF

kubectl apply -f service4-cloudep-ing.yaml
```

####  Template OpenAPI Spec from ConfigMap and Ingress: 

```sh
PROJECT=$(gcloud config get-value project)

cat > service5-cloudep-cm-ing.yaml <<EOF
apiVersion: v1
kind: ConfigMap 
metadata: 
  name: service5-openapi-spec 
data: 
  spec: |-
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "ConfigMap Template: service5"
      version: "1.0.0"
    basePath: "/"
    consumes:
    - "application/json"
    produces:
    - "application/json"
    schemes:
    - "http"
    - "https"
    paths:
      "/**":
        get:
          operationId: Get
          responses:
            '200':
              description: Get
            default:
              description: Error
        delete:
          operationId: Delete
          responses:
            '204':
              description: Delete
            default:
              description: Error
        patch:
          operationId: Patch
          responses:
            '200':
              description: Patch
            default:
              description: Error
        post:
          operationId: Post
          responses:
            '200':
              description: Post
            default:
              description: Error
        put:
          operationId: Put
          responses:
            '200':
              description: Put
            default:
              description: Error
    {{- if .JWTAudiences }}
    security:
    - google_jwt: []
    securityDefinitions:
      google_jwt:
        authorizationUrl: ""
        flow: "implicit"
        type: "oauth2"
        x-google-issuer: "https://cloud.google.com/iap"
        x-google-jwks_uri: "https://www.gstatic.com/iap/verify/public_key-jwk"
        x-google-audiences: "{{ StringsJoin .JWTAudiences "," }}}"
     {{ end }}
    host: "{{.Endpoint}}"
    x-google-endpoints:
    - name: "{{.Endpoint}}"
      target: "{{.Target}}"
--- 
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: service5-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - host: service5.endpoints.${PROJECT}.cloud.goog
    http:
      paths:
      - path:
        backend:
          serviceName: service5
          servicePort: 80
---
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: service5
spec:
  project: ${PROJECT}
  targetIngress:
    name: service5-ingress
    namespace: default
    jwtServices:
    - service5
  openAPISpecConfigMap: 
    name: service5-openapi-spec
    key: spec
--- 
apiVersion: v1
kind: Service
metadata:
  name: service5
spec:
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: service5
  type: NodePort
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: service5
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: service5
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
            scheme: HTTP
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 2
EOF

kubectl apply -f service5-cloudep-cm-ing.yaml
```