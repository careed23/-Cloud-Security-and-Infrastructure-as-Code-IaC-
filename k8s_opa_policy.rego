package kubernetes.security.policy

# --- Policy 1: Prevent running container as root ---
# Deny deployment if securityContext is not defined or if runAsUser is set to 0 (root)
deny_root_user[msg] {
    # Check for container specs across Deployment, DaemonSet, etc.
    container := input.request.object.spec.template.spec.containers[_]
    
    # Check 1: runAsUser is not explicitly set (defaults may be insecure)
    not container.securityContext.runAsUser
    msg := "Security violation: Container securityContext.runAsUser must be explicitly set to a non-zero value to prevent running as root."
}

deny_root_user[msg] {
    container := input.request.object.spec.template.spec.containers[_]
    # Check 2: runAsUser is explicitly set to 0 (root)
    container.securityContext.runAsUser == 0
    msg := "Security violation: Running containers as root (runAsUser: 0) is forbidden."
}

# --- Policy 2: Forbid the ':latest' image tag ---
# Deny deployment if any container image uses the ':latest' tag, 
# as it is non-deterministic and prevents secure rollback/auditing.
deny_latest_tag[msg] {
    container := input.request.object.spec.template.spec.containers[_]
    
    # Split the image string by ':'
    image_parts := split(container.image, ":")
    
    # Check if the last part (the tag) is 'latest' or if no tag is provided (implying 'latest')
    image_parts[count(image_parts)-1] == "latest"
    msg := "Security violation: Use of the ':latest' image tag is forbidden. Use a specific, immutable tag (e.g., v1.2.3) for auditable and reproducible deployments."
}
