
TEST_ARTIFACTS := service1-cloudep.yaml service2-simple-cloudep.yaml service3-simple-ingress-cloudep.yaml service3-deployment.yaml service3-ingress.yaml service4-cloudep-template-spec-ing.yaml service5-template-cm-spec-ing.yaml
PHASE2_TEST_ARTIFACTS := service5-configmap-update.yaml
project:
	$(eval PROJECT := $(shell gcloud config get-value project))

define TEST_SERVICE
apiVersion: ctl.isla.solutions/v1
kind: CloudEndpoint
metadata:
  name: {{NAME}}
spec:
  project: {{PROJECT}}
  openAPISpec: |-
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "{{TITLE}}: {{NAME}}"
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
define TEST_SERVICE_SPEC_INGRESS_CLOUDEP
$(call TEST_INGRESS)
--- 
$(call TEST_SERVICE)
  targetIngress:
    name: {{INGRESS_NAME}}
    namespace: default
    jwtServices:
    - {{NAME}}
---
$(call TEST_APP)
endef
define TEST_SERVICE_SPEC_CONFIGMAP_SPEC
apiVersion: v1
kind: ConfigMap 
metadata: 
  name: {{NAME}}-openapi-spec
data: 
  spec: |-
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "ConfigMap Template: {{NAME}}"
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
    host: "{{HOSTNAME}}"
    x-google-endpoints:
    - name: "{{HOSTNAME}}"
      target: "{{IP_ADDRESS}}"

--- 
$(call TEST_INGRESS)
---
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
    - {{NAME}}
  openAPISpecConfigMap: 
    name: {{NAME}}-openapi-spec
    key: spec
--- 
$(call TEST_APP)
endef 

define CHANGED_CONFIGMAP
apiVersion: v1
kind: ConfigMap 
metadata: 
  name: {{NAME}}-openapi-spec 
data: 
  spec: |-
    swagger: "2.0"
    info:
      description: "wildcard config for any HTTP service."
      title: "Template: {{NAME}} Changed"
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
    host: "{{HOSTNAME}}"
    x-google-endpoints:
    - name: "{{HOSTNAME}}"
      target: "{{IP_ADDRESS}}"
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
	-e "s/{{TITLE}}/Test Spec/g" \
	-e "s/{{PROJECT}}/$(PROJECT)/g" \
	-e "s/{{HOSTNAME}}/service$*.endpoints.$(PROJECT).cloud.goog/g" \
	-e "s/{{IP_ADDRESS}}/0\.0\.0\.0/g" \
	-e "s/{{JWT_AUDIENCE}}//g" \
	> $@

export TEST_SERVICE_SPEC_INGRESS_CLOUDEP
service%-cloudep-template-spec-ing.yaml: project
	@echo "$${TEST_SERVICE_SPEC_INGRESS_CLOUDEP}" | \
	sed -e "s/{{NAME}}/service$*/g" \
	-e "s/{{TITLE}}/Test Template Spec/g" \
	-e "s/{{PROJECT}}/$(PROJECT)/g" \
	-e "s/{{HOSTNAME}}/{{.Endpoint}}/g" \
	-e "s/{{IP_ADDRESS}}/{{.Target}}/g" \
	-e "s/{{INGRESS_NAME}}/service$*-ingress/g" \
	> $@

export TEST_SERVICE_SPEC_CONFIGMAP_SPEC
service%-template-cm-spec-ing.yaml: project
	@echo "$${TEST_SERVICE_SPEC_CONFIGMAP_SPEC}" | \
	sed -e "s/{{NAME}}/service$*/g" \
	-e "s/{{TITLE}}/ConfigMap Template Spec/g" \
	-e "s/{{HOSTNAME}}/{{.Endpoint}}/g" \
	-e	"s/{{PROJECT}}/$(PROJECT)/g" \
	-e "s/{{IP_ADDRESS}}/{{.Target}}/g" \
	-e "s/{{INGRESS_NAME}}/service$*-ingress/g" \
	> $@

export CHANGED_CONFIGMAP
service%-configmap-update.yaml: project 
	@echo "$${CHANGED_CONFIGMAP}" | \
	sed -e "s/{{NAME}}/service$*/g" \
	-e "s/{{HOSTNAME}}/{{.Endpoint}}/g" \
	-e "s/{{IP_ADDRESS}}/{{.Target}}/g" \
	> $@

THIS_FILE := $(lastword $(MAKEFILE_LIST))

test-watched: $(PHASE2_TEST_ARTIFACTS)
	$(shell sleep 120s)
	-@for f in $^; do kubectl apply -f $$f; done 

test: $(TEST_ARTIFACTS)
	-@for f in $^; do kubectl apply -f $$f; done
	@$(MAKE) -f $(THIS_FILE) test-watched 

test-stop: $(TEST_ARTIFACTS)
	-@for f in $^; do kubectl delete -f $$f; done

test-clean: $(TEST_ARTIFACTS) $(PHASE2_TEST_ARTIFACTS)
	rm -f $^