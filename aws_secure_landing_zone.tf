/*
  AWS Secure Reference Architecture / Landing Zone
  
  This conceptual Terraform code defines a foundational secure environment (Landing Zone) in AWS.
  It demonstrates:
  1. Isolated Networking (VPC with private subnets).
  2. Centralized Auditing (CloudTrail + S3 logging bucket).
  3. Secure Compute (EC2 with restrictive IAM Role and Security Group).
  4. Least Privilege IAM for the compute workload.
*/

variable "project_name" {
  description = "Short name used for tagging and resource prefixes."
  type        = string
  default     = "secure-landing-zone"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.project_name))
    error_message = "project_name must be 3-31 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the secure VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR range (example: 10.0.0.0/16)."
  }
}

variable "audit_log_retention_days" {
  description = "Retention period for S3 audit logs."
  type        = number
  default     = 365

  validation {
    condition     = var.audit_log_retention_days >= 90 && var.audit_log_retention_days <= 3653
    error_message = "audit_log_retention_days must be between 90 and 3653 days."
  }
}

variable "aws_region" {
  description = "AWS region used by the AWS provider."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment label used for resource tagging."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "environment must be one of: dev, stage, prod."
  }
}

locals {
  tags = {
    Project     = var.project_name
    Owner       = "security"
    ManagedBy   = "terraform"
    Environment = "prod"
  }
}

# --- 1. Centralized Logging & Auditing ---

# Dedicated S3 bucket for storing all logs and audit trails (CloudTrail, VPC Flow Logs)
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}"
  acl           = "log-delivery-write" # Required for AWS services to deliver logs
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket                  = aws_s3_bucket.audit_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit_logs.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  rule {
    id     = "expire-audit-logs"
    status = "Enabled"
    expiration {
      days = var.audit_log_retention_days
    }
  }
}

data "aws_iam_policy_document" "audit_logs" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.audit_logs.arn,
      "${aws_s3_bucket.audit_logs.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = data.aws_iam_policy_document.audit_logs.json
}

# --- KMS Key for Audit and Config Data ---
data "aws_iam_policy_document" "kms_audit_logs" {
  statement {
    sid     = "AllowAccountRoot"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "audit_logs" {
  description         = "KMS key for audit logs and AWS Config data."
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_audit_logs.json
  tags                = local.tags
}

resource "aws_kms_alias" "audit_logs" {
  name          = "alias/${var.project_name}-audit"
  target_key_id = aws_kms_key.audit_logs.key_id
}

# IAM Role for CloudTrail to write logs to CloudWatch (CRITICAL for real-time monitoring)
resource "aws_iam_role" "cloudtrail_logs" {
  name = "CloudTrailCWLogsRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_role_policy" "cloudtrail_logs_policy" {
  name = "CloudTrailCWLogsPolicy"
  role = aws_iam_role.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      },
    ]
  })
}

# CloudWatch Log Group for CloudTrail logs (Define mandatory log retention policy)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${aws_cloudtrail.main.name}"
  retention_in_days = 365
}

# Centralized Auditing via CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = "SecurityTrail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_logging                = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.audit_logs.arn
  
  # Link to CloudWatch Logs for real-time security event monitoring
  cloud_watch_logs_group_arn    = aws_cloudwatch_log_group.cloudtrail.arn
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_logs.arn
}

# --- 2. Isolated Networking (VPC) ---
# 
resource "aws_vpc" "secure_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, { Name = "${var.project_name}-vpc" })
}

# Private Subnets (where application compute resides, isolated from direct internet access)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.secure_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.secure_vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.tags, { Name = "${var.project_name}-private-${count.index}" })
}

# VPC Flow Logs to centralized audit bucket
resource "aws_flow_log" "vpc" {
  log_destination      = aws_s3_bucket.audit_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.secure_vpc.id
}

# --- 2b. Security Monitoring (GuardDuty) ---
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = local.tags
}

# --- 2c. Centralized Security Hub ---
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::standards/cis-aws-foundations-benchmark/v/1.2.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "pci_dss" {
  standards_arn = "arn:aws:securityhub:::standards/pci-dss/v/3.2.1"
  depends_on    = [aws_securityhub_account.main]
}

# --- 2d. Data Classification (Macie) ---
resource "aws_macie2_account" "main" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                      = "ENABLED"
}

# --- 2e. IAM Access Analysis ---
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "${var.project_name}-analyzer"
  type          = "ACCOUNT"
  tags          = local.tags
}

resource "aws_security_group" "compute" {
  name        = "${var.project_name}-compute-sg"
  description = "Default deny inbound; allow outbound HTTPS."
  vpc_id      = aws_vpc.secure_vpc.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-compute-sg" })
}

# --- 3. Secure Compute & Least Privilege IAM ---

# IAM Policy: Minimal required permissions for the application (Least Privilege)
resource "aws_iam_policy" "compute_policy" {
  name        = "SecureComputeMinimalAccess"
  description = "Allows only necessary read-only access to specific resources."
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = [
          "arn:aws:s3:::app-config-bucket/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# IAM Role attached to the Compute Environment (EC2/ECS/EKS nodes)
resource "aws_iam_role" "compute_role" {
  name               = "SecureComputeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "compute_attach" {
  role       = aws_iam_role.compute_role.name
  policy_arn = aws_iam_policy.compute_policy.arn
}

# --- 4. Continuous Compliance (AWS Config) ---
resource "aws_iam_role" "config" {
  name = "${var.project_name}-config-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-config-delivery"
  s3_bucket_name = aws_s3_bucket.audit_logs.bucket
  s3_key_prefix  = "config"
  s3_kms_key_arn  = aws_kms_key.audit_logs.arn
  depends_on     = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config.arn
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name = "${var.project_name}-s3-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

resource "aws_config_config_rule" "iam_password_policy" {
  name = "${var.project_name}-iam-password-policy"
  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }
  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireNumbers             = "true"
    RequireSymbols             = "true"
    MinimumPasswordLength      = "14"
    MaxPasswordAge             = "90"
  })
}

# --- Data Sources (required for configuration) ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
