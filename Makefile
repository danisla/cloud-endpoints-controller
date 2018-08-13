TAG = dev

all: install

install:
	go install

image:
	docker build -t gcr.io/cloud-solutions-group/cloud-endpoints-controller:$(TAG) .

push: image
	docker push gcr.io/cloud-solutions-group/cloud-endpoints-controller:$(TAG)

install-metacontroller:
	helm install --name metacontroller --namespace metacontroller charts/metacontroller

metalogs:
	kubectl -n metacontroller logs -f metacontroller-metacontroller-0

include test.mk