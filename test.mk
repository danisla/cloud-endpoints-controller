
TEST_ARTIFACTS := service1-cloudep.yaml service2-simple-cloudep.yaml service3-simple-ingress-cloudep.yaml service3-deployment.yaml service3-ingress.yaml

project:
	$(eval PROJECT := $(shell gcloud config get-value project))

define TEST_SERVICE
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: {{NAME}}
spec:
  project: disla-goog-com-csa-ext
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
    security:
    - google_jwt: []
    securityDefinitions:
      google_jwt:
        authorizationUrl: ""
        flow: "implicit"
        type: "oauth2"
        x-google-issuer: "https://cloud.google.com/iap"
        x-google-jwks_uri: "https://www.gstatic.com/iap/verify/public_key-jwk"
        x-google-audiences: "{{JWT_AUDIENCE}}"

    host: "{{HOSTNAME}}"
    x-google-endpoints:
    - name: "{{HOSTNAME}}"
      target: "{{IP_ADDRESS}}"
endef

define TEST_SERVICE_SIMPLE
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: {{NAME}}
spec:
  project: {{PROJECT}}
  target: {{IP_ADDRESS}}
endef

define TEST_SERVICE_INGRESS
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: {{NAME}}
spec:
  project: {{PROJECT}}
  targetIngress:
    name: {{INGRESS_NAME}}
    namespace: default
    jwtServices:
    - service3
endef

define TEST_APP
apiVersion: v1
kind: Service
metadata:
  name: {{NAME}}
spec:
  ports:
  - port: 80
    targetPort: 80
    name: http
  selector:
    app: {{NAME}}
  type: NodePort
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: {{NAME}}
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: {{NAME}}
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
endef

define TEST_INGRESS
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: {{NAME}}-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - host: {{NAME}}.endpoints.{{PROJECT}}.cloud.goog
    http:
      paths:
      - path:
        backend:
          serviceName: {{NAME}}
          servicePort: 80
endef

export TEST_APP
service%-deployment.yaml:
	@echo "$${TEST_APP}" | \
	  sed -e "s/{{NAME}}/service$*/g" \
	> $@

export TEST_SERVICE_INGRESS
service%-simple-ingress-cloudep.yaml: project
	@echo "$${TEST_SERVICE_INGRESS}" | \
	  sed -e "s/{{NAME}}/service$*/g" \
		-e "s/{{PROJECT}}/$(PROJECT)/g" \
	    -e "s/{{INGRESS_NAME}}/service$*-ingress/g" \
	  > $@

export TEST_INGRESS
service%-ingress.yaml: project
	@echo "$${TEST_INGRESS}" | \
	  sed -e "s/{{NAME}}/service$*/g" \
		-e "s/{{PROJECT}}/$(PROJECT)/g" \
	  > $@

export TEST_SERVICE_SIMPLE
service%-simple-cloudep.yaml: project
	@echo "$${TEST_SERVICE_SIMPLE}" | \
	  sed -e "s/{{NAME}}/service$*/g" \
		-e "s/{{PROJECT}}/$(PROJECT)/g" \
	    -e "s/{{IP_ADDRESS}}/0\.0\.0\.0/g" \
	  > $@

export TEST_SERVICE
service%-cloudep.yaml: project
	@echo "$${TEST_SERVICE}" | \
	  sed -e "s/{{NAME}}/service$*/g" \
	    -e "s/{{HOSTNAME}}/service$*.endpoints.$(PROJECT).cloud.goog/g" \
	    -e "s/{{IP_ADDRESS}}/0\.0\.0\.0/g" \
		-e "s/{{JWT_AUDIENCE}}//g" \
	  > $@

test: $(TEST_ARTIFACTS)
	-@for f in $^; do kubectl apply -f $$f; done

test-stop: $(TEST_ARTIFACTS)
	-@for f in $^; do kubectl delete -f $$f; done

test-clean: $(TEST_ARTIFACTS)
	rm -f $^