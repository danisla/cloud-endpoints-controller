FROM golang:1.10-alpine AS build
RUN apk add --update ca-certificates bash curl
RUN curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

COPY . /go/src/github.com/danisla/cloud-endpoints-controller/
WORKDIR /go/src/github.com/danisla/cloud-endpoints-controller/cmd/cloud-endpoints-controller
RUN dep ensure && go install

FROM alpine:3.7
RUN apk add --update ca-certificates bash curl
COPY --from=build /go/bin/cloud-endpoints-controller /usr/bin/
CMD ["/usr/bin/cloud-endpoints-controller"]