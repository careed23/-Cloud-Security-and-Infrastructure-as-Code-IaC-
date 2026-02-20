package kubernetes.security.policy

secure_container := {
	"name": "app",
	"image": "nginx:1.2.3",
	"securityContext": {
		"runAsUser": 1000,
		"runAsNonRoot": true,
		"allowPrivilegeEscalation": false,
		"readOnlyRootFilesystem": true,
		"privileged": false,
	},
	"resources": {"limits": {
		"cpu": "100m",
		"memory": "128Mi",
	}},
}

good_input := {"request": {"object": {"spec": {"template": {"spec": {
	"hostNetwork": false,
	"containers": [secure_container],
}}}}}}

latest_tag_input := {"request": {"object": {"spec": {"template": {"spec": {
	"hostNetwork": false,
	"containers": [object.union(secure_container, {"image": "nginx:latest"})],
}}}}}}

root_user_input := {"request": {"object": {"spec": {"template": {"spec": {
	"hostNetwork": false,
	"containers": [object.remove(secure_container, ["securityContext", "runAsUser"])],
}}}}}}

privilege_escalation_input := {"request": {"object": {"spec": {"template": {"spec": {
	"hostNetwork": false,
	"containers": [object.union(secure_container, {"securityContext": object.union(secure_container.securityContext, {"allowPrivilegeEscalation": true})})],
}}}}}}

test_allow_secure_deployment if {
	count(data.kubernetes.security.policy.deny_root_user) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_latest_tag) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_privileged_container) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_privilege_escalation) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_readonly_root_fs) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_resource_limits) == 0 with input as good_input
	count(data.kubernetes.security.policy.deny_host_network) == 0 with input as good_input
}

test_deny_root_user_missing if {
	count(data.kubernetes.security.policy.deny_root_user) > 0 with input as root_user_input
}

test_deny_latest_tag if {
	count(data.kubernetes.security.policy.deny_latest_tag) > 0 with input as latest_tag_input
}

test_deny_privilege_escalation if {
	count(data.kubernetes.security.policy.deny_privilege_escalation) > 0 with input as privilege_escalation_input
}
