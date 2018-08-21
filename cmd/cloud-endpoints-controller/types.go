package main

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// CloudEndpointControllerState represents the string mapping of the possible controller states. See the const definition below for enumerated states.
type CloudEndpointControllerState string

const (
	//StateIdle means there are no more changes pending
	StateIdle = "IDLE"
	//StateEndpointCreatePending means the endpoint is pending creation
	StateEndpointCreatePending = "ENDPOINT_CREATE_PENDING"
	//StateEndpointSubmitPending means the endpoint is pending submission
	StateEndpointSubmitPending = "ENDPOINT_SUBMIT_PENDING"
	//StateEndpointRolloutPending means the endpoint is pending rollout
	StateEndpointRolloutPending = "ENDPOINT_ROLLOUT_PENDING" // Pending Rollout
)

// SyncRequest describes the payload from the CompositeController hook
type SyncRequest struct {
	Parent   CloudEndpoint                          `json:"parent"`
	Children CloudEndpointControllerRequestChildren `json:"children"`
}

// SyncResponse is the CompositeController response structure.
type SyncResponse struct {
	Status   CloudEndpointControllerStatus `json:"status"`
	Children []interface{}                 `json:"children"`
}

// CloudEndpointControllerRequestChildren is the children definition passed by the CompositeController request for the CloudEndpoint controller.
type CloudEndpointControllerRequestChildren struct {
}

// CloudEndpointControllerStatus is the status structure for the custom resource
type CloudEndpointControllerStatus struct {
	LastAppliedSig string   `json:"lastAppliedSig"`
	StateCurrent   string   `json:"stateCurrent"`
	ConfigSubmit   string   `json:"configSubmit,omitempty"`
	ServiceRollout string   `json:"serviceRollout,omitempty"`
	Endpoint       string   `json:"endpoint"`
	Config         string   `json:"config"`
	IngressIP      string   `json:"ingressIP"`
	JWTAudiences   []string `json:"jwtAudiences"`
	ConfigMapHash  string   `json:"configMapHash"`
}

// CloudEndpoint is the custom resource definition structure.
type CloudEndpoint struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              CloudEndpointSpec             `json:"spec,omitempty"`
	Status            CloudEndpointControllerStatus `json:"status"`
}

// CloudEndpointConfigMapSpec is the subspec for CloudEndpointSpec that contains a reference to a configMap containing the Open API spec
type CloudEndpointConfigMapSpec struct {
	Name string `json:"name"`
	Key  string `json:"key"`
}

// CloudEndpointSpec mirrors the IngressSpec with added IAPProjectAuthz spec and a custom Rules spec.
type CloudEndpointSpec struct {
	Project              string                         `json:"project,omitempty"`
	Target               string                         `json:"target,omitempty"`
	TargetIngress        CloudEndpointTargetIngressSpec `json:"targetIngress,omitempty"`
	OpenAPISpec          map[string]interface{}         `json:"openAPISpec,omitempty"`
	OpenAPISpecConfigMap CloudEndpointConfigMapSpec     `json:"openAPISpecConfigMap"`
}

// CloudEndpointTargetIngressSpec is the format for the targetIngress spec
type CloudEndpointTargetIngressSpec struct {
	Name        string   `json:"name,omitempty"`
	Namespace   string   `json:"namespace,omitempty"`
	JWTServices []string `json:"jwtServices,omitempty"`
}
