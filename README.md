# 🚀 Staff-Level Cloud Security Reference Architecture: IaC & Policy as Code

[![Cloud Platform](https://img.shields.io/badge/Cloud-AWS%2FGCP-blue?style=flat-square)]()
[![IaC/PaC Tools](https://img.shields.io/badge/IaC%2FPaC-Terraform%2FRego-000000?style=flat-square)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)]()
[![Maintainer](https://img.shields.io/badge/Maintainer-@careed23-purple?style=flat-square)]()
<br>

This repository contains a secure, production-ready baseline for cloud infrastructure, demonstrating the ability to define and enforce organizational security standards through code.

<kbd>Cloud: AWS/GCP</kbd> <kbd>IaC: Terraform/Rego</kbd> <kbd>License: MIT</kbd> <kbd>Maintainer: @careed23</kbd>

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

⏩ This demonstrates the ability to translate high-level security requirements into immediate, executable, and enforced policies at the deployment level. It successfully achieves "shifting security left" by stopping risks before they ever enter the production environment.
