<div align="center">

# 🔒 Cloud Security Reference Architecture: IaC & Policy as Code 🚀

![Cloud](https://img.shields.io/badge/Cloud-AWS%2FGCP-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Terraform%2FPaC-blue?style=for-the-badge&logo=terraform&logoColor=white)
![Rego](https://img.shields.io/badge/Policy%20as%20Code-Rego-informational?style=for-the-badge&logo=open-policy-agent&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Maintainer](https://img.shields.io/badge/Maintainer-%40careed23-purple?style=for-the-badge&logo=github&logoColor=white)

<br>

**This repository contains a secure, production-ready baseline for cloud infrastructure, demonstrating the ability to define and enforce organizational security standards through code.**

</div>

---

## 📖 Table of Contents
* [Core Security Philosophy](#core-security-philosophy)
    * [1. Secure Reference Architecture (AWS Landing Zone)](#1-secure-reference-architecture-aws-landing-zone)
        * [Component Breakdown](#component-breakdown)
* [Security Rationale](#security-rationale)
    * [Networking (VPC & Subnets)](#networking-vpc--subnets)
    * [Centralized Auditing](#centralized-auditing-cloudtrails3cloudwatch)
    * [Least Privilege IAM](#least-privilege-iam)
* [Installation](#installation)
    * [Essential Tools](#1-essential-tools)
    * [Cloud Provider Access Configuration](#2-cloud-provider-access-configuration)
* [Usage Examples](#usage-examples)
    * [Security Policy Validation (PaC)](#1-security-policy-validation-policy-as-code---pac)
    * [Infrastructure Deployment (IaC)](#2-infrastructure-deployment-infrastructure-as-code---iac)
* [CI/CD Pipeline Integration](#cicd-pipeline-integration)
* [Contributing](#contributing)
* [License](#license)

---

## 💡 Core Security Philosophy

This architecture demonstrates a comprehensive approach to securing a cloud environment by enforcing security and compliance **proactively** at creation time (IaC) and **reactively** at deployment time (PaC). This dual-layered governance model ensures security is intrinsic, not external, to the development lifecycle.

### 1. Secure Reference Architecture (AWS Landing Zone)
The Terraform configuration defines a **Secure Landing Zone**—a non-negotiable, mandated baseline that all applications must inherit to ensure foundational security and compliance.

#### Component Breakdown
*(Add more details on components here, perhaps a table or bullet points)*

---

## 🛡️ Security Rationale

### Networking (VPC & Subnets)
The use of **Only Private Subnets** for compute resources ensures workloads are shielded from direct public exposure, prioritizing isolation and minimizing the attack surface. (Defense-in-Depth)

### Centralized Auditing (CloudTrail/S3/CloudWatch)
All API activity is logged globally, encrypted, and stored in an immutable S3 bucket, streamed to CloudWatch for real-time security monitoring and anomaly detection. This ensures non-repudiation.

### Least Privilege IAM
The `SecureComputeRole` is defined with an explicit, minimal compute_policy granting only the permissions absolutely necessary for the application's function. This strictly enforces the **Principle of Least Privilege**, preventing lateral movement and minimizing blast radius.

---

## 🛠️ Installation

This project requires three main components: essential command-line tools, cloud access configuration for AWS and/or GCP, and preparation of the local repository.

### 1. Essential Tools
Install the following tools on your local machine to manage the Infrastructure as Code (IaC) and Policy as Code (PaC) components.

| Tool | Purpose | Installation Guide |
| :--- | :--- | :--- |
| **Terraform** | IaC provisioning tool. | [Install Terraform on Windows, Linux, and macOS](https://phoenixnap.com/kb/how-to-install-terraform) |
| **Open Policy Agent (OPA)** | Required for Rego policy validation. | [Install OPA](https://www.openpolicyagent.org/docs/latest/#getting-started) |
| **AWS CLI** | Required for AWS authentication and service interaction. | [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| **gcloud CLI** | Required for GCP authentication and service interaction. | [Install Google Cloud SDK](https://cloud.google.com/sdk/docs/install) |

### 2. Cloud Provider Access Configuration
Terraform requires environment-specific credentials to deploy resources. We recommend using **Application Default Credentials (ADC)** or role-based access.

#### A. Amazon Web Services (AWS) Setup
1.  **Authenticate:** Run `aws configure` and enter your AWS credentials.
2.  **Best Practice:** Utilize **IAM Roles** or **IAM User credentials** with the minimum necessary permissions.

#### B. Google Cloud Platform (GCP) Setup
1.  **Log in (User Authentication):** Authenticate your user credentials for ADC: `gcloud auth application-default login`
2.  **Set Project ID:** `gcloud config set project [YOUR_GCP_PROJECT_ID]`
3.  **Best Practice:** For production, use a dedicated **Service Account**.

### 3. Repository Preparation
1.  **Clone the Repository:**
    ```bash
    git clone [REPO_URL]
    cd staff-level-cloud-security-architecture
    ```
2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

---

## 🚀 Usage Examples

### 1. Security Policy Validation (Policy as Code - PaC)
Validate your configuration against the security policies defined in `policy/rego/` using **Open Policy Agent (OPA)** before deployment.

| Step | Command | Description |
| :--- | :--- | :--- |
| **A. Test Policies** | `opa test policy/rego/ --verbose` | Runs all unit tests for Rego policies. |
| **B. Evaluate Configuration** | `opa eval -i main.tf -d policy/rego/ -q 'data.policy.allow' ` | Evaluates Terraform config against policies. `allow` must be `true`. |

### 2. Infrastructure Deployment (Infrastructure as Code - IaC)
Manage the cloud resources using the standard Terraform workflow.

| Step | Command | Description |
| :--- | :--- | :--- |
| **A. Plan Deployment** | `terraform plan -out=tfplan` | Calculates and saves the execution plan for review. |
| **B. Apply Changes** | `terraform apply "tfplan"` | Executes the planned changes to provision resources. |
| **C. Destruction** | `terraform destroy` | Safely removes all provisioned resources (use with caution). |

---

## 🏗️ CI/CD Pipeline Integration

Integrating this architecture into a CI/CD pipeline ensures security checks (PaC) are mandatory before infrastructure changes (IaC) are applied, enforcing your compliance baseline on every commit.

### Pipeline Commands (Example for a Branch Merge)

#### 1. Prepare and Initialize
```bash
terraform init -backend-config="key=$CI_PROJECT_NAME/$CI_COMMIT_REF_SLUG.tfstate"
