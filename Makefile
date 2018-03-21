SHELL := /bin/bash

APP := cloud-endpoints-controller
CHART_DIR := charts/cloud-endpoints-controller
NS := metacontroller
DEPS :=
GODEV_PATH := github.com/danisla/cloud-endpoints-controller
GODEV_BUILD_SUBDIR := ./cmd/cloud-endpoints-controller
DEVSHELL=bash
IMAGE_PROJECT=cloud-solutions-group

NFS_CHART_DIR := charts/nfs-server
NFS_HOST := godev-nfs-nfs-server.$(NS).svc.cluster.local

define get_pod
$(shell kubectl get pods -n $(NS) -l app=$(APP) -o jsonpath='{.items..metadata.name}')
endef

define get_metapod
$(shell kubectl get pods -n $(NS) -l app=kube-metacontroller -o jsonpath='{.items..metadata.name}')
endef

define wait_pod
$(shell while [[ $$(kubectl get pods -n $(NS) -l app=$(APP) -o json | jq -r '.items[] | select(.status.containerStatuses[].ready == true) | .metadata.name' | wc -l) -ne 2 ]]; do \
  echo "Waiting for deployment..." 1>&2; \
  sleep 2; \
done)
endef

install: install-nfs install-chart wait deps build

install-kube-metacontroller:
	  @helm install --name metacontroller --namespace metacontroller charts/kube-metacontroller

install-nfs:
	(cd $(NFS_CHART_DIR) && \
	helm install --name godev-nfs --namespace=$(NS) .)

install-chart: $(DEPS)
	(cd $(CHART_DIR) && \
	helm install --name $(APP) --namespace=$(NS) --set godev.enabled=true,godev.persistence.nfsHost=$(NFS_HOST) .)

install-chart-prod: $(DEPS)
	(cd $(CHART_DIR) && \
	helm install --name $(APP) --namespace=$(NS) .)

uninstall-chart:
	-helm delete --purge $(APP)

reinstall: uninstall-chart install-chart wait dev-cp deps build

upgrade: upgrade-chart wait

upgrade-chart:
	(cd $(CHART_DIR) && \
	helm upgrade $(APP) .)

deps: dev-cp
	@echo "Installing go deps with dep..." && kubectl exec -n $(NS) -c godev -it $(call get_pod) -- bash -c 'cd /go/src/$(GODEV_PATH) && dep ensure'

$(CHART_DIR)/%:
	$(error prerequisite file not found: $@)

wait:
	$(call wait_pod)

dev-cp:
	$(eval TMP_DIR := /tmp/$(notdir $(shell mktemp -d)))
	@POD=$(call get_pod) && echo "Copying ./ to $${POD}:/go/src/$(GODEV_PATH)/" && kubectl cp -n $(NS) -c godev ./ $${POD}:$(TMP_DIR) && \
	kubectl exec -n $(NS) -c godev -it $${POD} -- bash -c 'mkdir -p /go/src/$(GODEV_PATH) && rsync -ra $(TMP_DIR)/ /go/src/$(GODEV_PATH)/ && rm -rf $(TMP_DIR)'

build: dev-cp
	@echo "Building $(GODEV_BUILD_SUBDIR)..." && kubectl exec -n $(NS) -c godev -it $(call get_pod) -- bash -c 'cd /go/src/$(GODEV_PATH) && go install $(GODEV_BUILD_SUBDIR)'

lpods:
	kubectl get pods -n $(NS)

podlogs:
	kubectl logs -n $(NS) -c $(APP) --tail=100 -f $(call get_pod)

devlogs:
	kubectl logs -n $(NS) -c godev --tail=100 -f $(call get_pod)

metalogs:
	kubectl logs -n $(NS) --tail=100 -f $(call get_metapod)

shell:
	@kubectl exec -n $(NS) -c $(APP) -it $(call get_pod) -- $(DEVSHELL)

devshell:
	@kubectl exec -n $(NS) -c godev -it $(call get_pod) -- $(DEVSHELL)

image:
	gcloud container builds submit --project $(IMAGE_PROJECT) --config cloudbuild.yaml .

clean:
	-helm delete --purge $(APP)
	-helm delete --purge godev-nfs
	-helm delete --purge metacontroller
	-kubectl delete secret -n metacontroller $(APP)-sa

include test.mk