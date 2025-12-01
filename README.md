🔒 Staff-Level Cloud Security Reference Architecture: IaC & Policy as Code 🚀

This repository contains a secure, production-ready baseline for cloud infrastructure, demonstrating the ability to define and enforce organizational security standards through code.

Cloud: AWS/GCP IaC: Terraform/Rego License: MIT Maintainer: @careed23

💡 Core Security Philosophy

This architecture demonstrates a comprehensive approach to securing a cloud environment by enforcing security and compliance proactively at creation time (IaC) and reactively at deployment time (PaC). This dual-layered governance model ensures security is intrinsic, not external, to the development lifecycle.

1. Secure Reference Architecture (AWS Landing Zone) ☁️

The Terraform configuration defines a Secure Landing Zone—a non-negotiable, mandated baseline that all applications must inherit to ensure foundational security and compliance.

Component Breakdown

Component

🛡️ Security Rationale

Networking (VPC & Subnets)

The use of only Private Subnets for compute resources ensures workloads are shielded from direct public exposure, prioritizing isolation and minimizing the attack surface. (Defense-in-Depth)

Centralized Auditing (CloudTrail/S3/CloudWatch)

All API activity is logged globally, encrypted, and stored in an immutable S3 bucket, streamed to CloudWatch for real-time security monitoring and anomaly detection. This ensures non-repudiation.

Least Privilege IAM

The SecureComputeRole is defined with an explicit, minimal compute_policy granting only the permissions absolutely necessary for the application's function. This strictly enforces the Principle of Least Privilege, preventing lateral movement.

Staff-Level Impact (IaC):

🎯 Defining this single source of truth for IaC prevents the decentralized creation of shadow IT and insecure deployments. This massively lowers the blast radius of misconfigurations and establishes a high-bar organizational security baseline across all environments.

2. Admission Controller / Policy as Code (PaC) ⚙️

The Rego policy (OPA) is implemented as a Kubernetes Admission Controller, acting as a mandatory security gate in the deployment pipeline. It evaluates resource requests before they are committed to the cluster API server.

Policy Enforcement

Policy

🛑 Security Rationale

deny_root_user

Enforces the container security standard that processes must not run with root privileges (runAsUser: 0). This is crucial for preventing privilege escalation if the container is exploited.

deny_latest_tag

The :latest tag is mutable and non-deterministic. This policy forces the use of immutable, versioned tags (e.g., v1.2.3), ensuring that deployments are auditable and reproducible for security reviews and fast, guaranteed rollbacks.

Staff-Level Impact (PaC):

⏩ This demonstrates the ability to translate high-level security requirements into immediate, executable, and enforced policies at the deployment level. It successfully achieves "shifting security left" by stopping risks before they ever enter the production environment.                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> The use of only **Private Subnets** for compute resources ensures workloads are not directly exposed to the internet, prioritizing isolation.
                    </p>
                </div>

                <!-- Component Card: Auditing -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-indigo-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-indigo-400 mb-2">Centralized Auditing</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> All API activity is logged globally and written to an immutable, encrypted S3 bucket and streamed to CloudWatch. This ensures **non-repudiation** and provides real-time monitoring for security anomalies.
                    </p>
                </div>

                <!-- Component Card: IAM -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-indigo-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-indigo-400 mb-2">Least Privilege IAM</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> The `SecureComputeRole` is defined with an explicit, minimal `compute_policy`. This prevents lateral movement by adhering strictly to the **Principle of Least Privilege**.
                    </p>
                </div>
            </div>

            <!-- Impact Summary -->
            <div class="mt-8 bg-indigo-900/30 p-4 rounded-lg border-l-4 border-indigo-500">
                <p class="font-medium text-sm text-indigo-300 uppercase">Staff-Level Impact (IaC):</p>
                <p class="text-gray-300 text-base">Defining this single source of truth for IaC prevents decentralized, insecure deployments and drastically lowers the blast radius of misconfigurations across the organization.</p>
            </div>
        </section>

        <!-- 2. Admission Controller / Policy as Code (PaC) -->
        <section class="mb-12">
            <h2 class="text-2xl sm:text-3xl font-bold mb-6 text-yellow-300 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-6 h-6 mr-3 text-yellow-500"><path d="M12 21.6c-4.4 0-8-3.6-8-8v-6.6c0-1.1.9-2 2-2h12c1.1 0 2 .9 2 2v6.6c0 4.4-3.6 8-8 8z"></path><path d="M12 17v-4"></path></svg>
                2. Admission Controller / Policy as Code (PaC)
            </h2>
            <p class="mb-6 text-gray-400">
                The Rego policy (OPA) acts as a **mandatory security gate** in the deployment pipeline, operating *before* a resource is committed to the API server. 
            </p>

            <div class="grid md:grid-cols-2 gap-6">
                <!-- Policy Card: Deny Root -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-red-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-red-400 mb-2 font-mono">`deny_root_user`</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> Enforces the critical standard that processes inside containers must not run with root privileges. This is a fundamental defense-in-depth measure to prevent **privilege escalation** upon container compromise.
                    </p>
                </div>

                <!-- Policy Card: Deny Latest -->
                <div class="bg-gray-800 p-5 rounded-xl border border-gray-700 hover:border-red-500 transition duration-300">
                    <h3 class="font-semibold text-lg text-red-400 mb-2 font-mono">`deny_latest_tag`</h3>
                    <p class="text-sm text-gray-400">
                        <span class="font-medium text-white">Security Rationale:</span> Forcing the use of immutable, versioned tags (e.g., `v1.2.3`) ensures that deployments are **auditable** and **reproducible** (secure rollbacks are guaranteed). The `:latest` tag is mutable and non-deterministic.
                    </p>
                </div>
            </div>

            <!-- Impact Summary -->
            <div class="mt-8 bg-red-900/30 p-4 rounded-lg border-l-4 border-red-500">
                <p class="font-medium text-sm text-red-300 uppercase">Staff-Level Impact (PaC):</p>
                <p class="text-gray-300 text-base">This demonstrates the ability to translate high-level security requirements directly into executable, enforced policies at the deployment level, **shifting security left** into the CI/CD process.</p>
            </div>
        </section>

        <footer class="text-center mt-12 pt-6 border-t border-gray-700/50 text-gray-500 text-sm">
            Staff Engineering Security Reference &copy; 2025
        </footer>
    </div>

</body>
</html>
