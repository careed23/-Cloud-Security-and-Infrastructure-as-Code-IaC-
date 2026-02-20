.PHONY: help init init-backend fmt validate tflint checkov opa-fmt opa-test gitleaks precommit security-checks plan

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform without remote backend
	terraform init -backend=false

init-backend: ## Initialize Terraform with backend.hcl
	terraform init -backend-config=backend.hcl

fmt: ## Check Terraform formatting recursively
	terraform fmt -check -recursive

validate: ## Validate Terraform configuration
	terraform validate -no-color

tflint: ## Run Terraform linter
	tflint --init && tflint --recursive

checkov: ## Run IaC security scan
	checkov -d . --framework terraform

opa-fmt: ## Check Rego formatting
	opa fmt --fail k8s_opa_policy.rego k8s_opa_policy_test.rego

opa-test: ## Run OPA policy tests
	opa test . --verbose

gitleaks: ## Run secret scan
	gitleaks detect --source . --verbose

precommit: ## Run all configured pre-commit hooks
	pre-commit run --all-files

security-checks: fmt validate tflint opa-fmt opa-test gitleaks ## Run local security and quality checks

plan: ## Generate Terraform plan using local tfvars file
	terraform plan -var-file=terraform.tfvars
