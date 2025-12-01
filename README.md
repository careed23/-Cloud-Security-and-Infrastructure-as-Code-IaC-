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
