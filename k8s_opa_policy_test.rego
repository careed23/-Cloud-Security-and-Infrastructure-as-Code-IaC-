package kubernetes.security.policy

secure_container = {
    "name": "app",
    "image": "nginx:1.2.3",
    "securityContext": {
        "runAsUser": 1000,
        "runAsNonRoot": true,
        "allowPrivilegeEscalation": false,
        "readOnlyRootFilesystem": true,
        "privileged": false
    },
    "resources": {
        "limits": {
            "cpu": "100m",
            "memory": "128Mi"
        }
    }
}

good_input = {
    "request": {
        "object": {
            "spec": {
                "template": {
                    "spec": {
                        "hostNetwork": false,
                        "containers": [secure_container]
                    }
                }
            }
        }
    }
}

latest_tag_input = {
    "request": {
        "object": {
            "spec": {
                "template": {
                    "spec": {
                        "hostNetwork": false,
                        "containers": [object.union(secure_container, {"image": "nginx:latest"})]
                    }
                }
            }
        }
    }
}

root_user_input = {
    "request": {
        "object": {
            "spec": {
                "template": {
                    "spec": {
                        "hostNetwork": false,
                        "containers": [object.remove(secure_container, ["securityContext", "runAsUser"])]
                    }
                }
            }
        }
    }
}

privilege_escalation_input = {
    "request": {
        "object": {
            "spec": {
                "template": {
                    "spec": {
                        "hostNetwork": false,
                        "containers": [object.union(secure_container, {"securityContext": object.union(secure_container.securityContext, {"allowPrivilegeEscalation": true})})]
                    }
                }
            }
        }
    }
}

test_allow_secure_deployment {
    count(data.kubernetes.security.policy.deny_root_user with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_latest_tag with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_privileged_container with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_privilege_escalation with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_readonly_root_fs with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_resource_limits with input as good_input) == 0
    count(data.kubernetes.security.policy.deny_host_network with input as good_input) == 0
}

test_deny_root_user_missing {
    count(data.kubernetes.security.policy.deny_root_user with input as root_user_input) > 0
}

test_deny_latest_tag {
    count(data.kubernetes.security.policy.deny_latest_tag with input as latest_tag_input) > 0
}

test_deny_privilege_escalation {
    count(data.kubernetes.security.policy.deny_privilege_escalation with input as privilege_escalation_input) > 0
}
