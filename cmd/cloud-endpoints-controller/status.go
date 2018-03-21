package main

func makeStatus(parent *CloudEndpoint, children *CloudEndpointControllerRequestChildren) *CloudEndpointControllerStatus {
	status := CloudEndpointControllerStatus{
		StateCurrent: "IDLE",
		JWTAudiences: make([]string, 0),
	}

	changed := false
	sig := calcParentSig(parent, "")

	if parent.Status.LastAppliedSig != "" {
		if parent.Status.StateCurrent == StateIdle && sig != parent.Status.LastAppliedSig {
			changed = true
			status.LastAppliedSig = ""
		} else {
			status.LastAppliedSig = parent.Status.LastAppliedSig
		}
	}

	if parent.Status.StateCurrent != "" && changed == false {
		status.StateCurrent = parent.Status.StateCurrent
	}

	if parent.Status.Endpoint != "" && changed == false {
		status.Endpoint = parent.Status.Endpoint
	}

	if parent.Status.Config != "" && changed == false {
		status.Config = parent.Status.Config
	}

	if parent.Status.ConfigSubmit != "" && changed == false {
		status.ConfigSubmit = parent.Status.ConfigSubmit
	}

	if parent.Status.ServiceRollout != "" && changed == false {
		status.ServiceRollout = parent.Status.ServiceRollout
	}

	if parent.Status.JWTAudiences != nil && changed == false {
		status.JWTAudiences = parent.Status.JWTAudiences
	}

	return &status
}
