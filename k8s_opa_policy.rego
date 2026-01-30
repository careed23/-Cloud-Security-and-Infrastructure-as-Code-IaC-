package kubernetes.security.policy

# Collect all containers (including init containers) for consistent checks
containers[container] {
    container := input.request.object.spec.template.spec.containers[_]
}

containers[container] {
    container := input.request.object.spec.template.spec.initContainers[_]
}

# --- Policy 1: Prevent running container as root ---
# Deny deployment if securityContext is not defined or if runAsUser is set to 0 (root)
deny_root_user[msg] {
    container := containers[_]
    
    # Check 1: runAsUser is not explicitly set (defaults may be insecure)
    not container.securityContext.runAsUser
    msg := "Security violation: Container securityContext.runAsUser must be explicitly set to a non-zero value to prevent running as root."
}

deny_root_user[msg] {
    container := containers[_]
    # Check 2: runAsUser is explicitly set to 0 (root)
    container.securityContext.runAsUser == 0
    msg := "Security violation: Running containers as root (runAsUser: 0) is forbidden."
}

# --- Policy 2: Forbid the ':latest' image tag ---
# Deny deployment if any container image uses the ':latest' tag, 
# as it is non-deterministic and prevents secure rollback/auditing.
deny_latest_tag[msg] {
    container := containers[_]
    
    # Split the image string by ':'
    image_parts := split(container.image, ":")
    
    # Check if the last part (the tag) is 'latest' or if no tag is provided (implying 'latest')
    image_parts[count(image_parts)-1] == "latest"
    msg := "Security violation: Use of the ':latest' image tag is forbidden. Use a specific, immutable tag (e.g., v1.2.3) for auditable and reproducible deployments."
}

# --- Policy 3: Disallow privileged containers ---
deny_privileged_container[msg] {
    container := containers[_]
    container.securityContext.privileged == true
    msg := "Security violation: privileged containers are forbidden."
}

# --- Policy 4: Prevent privilege escalation ---
deny_privilege_escalation[msg] {
    container := containers[_]
    not container.securityContext.allowPrivilegeEscalation == false
    msg := "Security violation: allowPrivilegeEscalation must be explicitly set to false."
}

# --- Policy 5: Require read-only root filesystem ---
deny_readonly_root_fs[msg] {
    container := containers[_]
    not container.securityContext.readOnlyRootFilesystem == true
    msg := "Security violation: readOnlyRootFilesystem must be set to true."
}

# --- Policy 6: Require CPU and memory limits ---
deny_resource_limits[msg] {
    container := containers[_]
    not container.resources.limits.cpu
    msg := "Security violation: CPU limits are required for all containers."
}

deny_resource_limits[msg] {
    container := containers[_]
    not container.resources.limits.memory
    msg := "Security violation: Memory limits are required for all containers."
}

# --- Policy 7: Disallow host networking ---
deny_host_network[msg] {
    input.request.object.spec.template.spec.hostNetwork == true
    msg := "Security violation: hostNetwork must be false."
}
