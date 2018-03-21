# Cloud Endpoints Controller

Controller for a Custom Resource Definition (CRD) that creates Cloud Endpoints services.

This controller does the following:

1. Creates a [Cloud Endpoints service and DNS record](https://cloud.google.com/endpoints/docs/openapi/naming-your-api-service) in the form of `SERVICE.endpoints.PROJECT_ID.cloud.goog`.
5. Deploys the OpenAPI spec to the Cloud Endpoints service.

See the chart [README.md](./charts/cloud-endpoints-controller/README.md) for details.