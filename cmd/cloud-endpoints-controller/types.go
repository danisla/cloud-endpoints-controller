package main

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// CloudEndpointControllerState represents the string mapping of the possible controller states. See the const definition below for enumerated states.
type CloudEndpointControllerState string

const (
	StateIdle                   = "IDLE"
	StateEndpointCreatePending  = "ENDPOINT_CREATE_PENDING"
	StateEndpointSubmitPending  = "ENDPOINT_SUBMIT_PENDING"
	StateEndpointRolloutPending = "ENDPOINT_ROLLOUT_PENDING"
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
}

// CloudEndpoint is the custom resource definition structure.
type CloudEndpoint struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              CloudEndpointSpec             `json:"spec,omitempty"`
	Status            CloudEndpointControllerStatus `json:"status"`
}

// CloudEndpointSpec mirrors the IngressSpec with added IAPProjectAuthz spec and a custom Rules spec.
type CloudEndpointSpec struct {
	Project       string                         `json:"project,omitempty"`
	Target        string                         `json:"target,omitempty"`
	TargetIngress CloudEndpointTargetIngressSpec `json:"targetIngress,omitempty"`
	OpenAPISpec   map[string]interface{}         `json:"openAPISpec,omitempty"`
}

// CloudEndpointTargetIngressSpec is the format for the targetIngress spec
type CloudEndpointTargetIngressSpec struct {
	Name        string   `json:"name,omitempty"`
	Namespace   string   `json:"namespace,omitempty"`
	JWTServices []string `json:"jwtServices,omitempty"`
}
