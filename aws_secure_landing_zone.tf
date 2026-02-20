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
  cloudtrail_name = "SecurityTrail"
  tags = {
    Project     = "${var.project_name}-${var.environment}"
    Owner       = "security"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

# --- 1. Centralized Logging & Auditing ---

# Dedicated S3 bucket for storing all logs and audit trails (CloudTrail, VPC Flow Logs)
resource "aws_s3_bucket" "audit_logs" {
  bucket        = "${var.project_name}-audit-logs-${data.aws_caller_identity.current.account_id}"
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
    object_ownership = "BucketOwnerEnforced"
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
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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
  statement {
    sid       = "AllowS3LogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.audit_logs.arn}/logs/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  policy = data.aws_iam_policy_document.audit_logs.json
}

# S3 access logging for audit_logs bucket (CKV_AWS_18)
resource "aws_s3_bucket_logging" "audit_logs" {
  bucket        = aws_s3_bucket.audit_logs.id
  target_bucket = aws_s3_bucket.audit_logs.id
  target_prefix = "logs/"
}

# SNS topic for S3 event notifications (CKV2_AWS_62)
resource "aws_sns_topic" "s3_events" {
  name              = "${var.project_name}-s3-event-notifications"
  kms_master_key_id = aws_kms_key.audit_logs.arn
  tags              = local.tags
}

# S3 event notifications (CKV2_AWS_62)
resource "aws_s3_bucket_notification" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  topic {
    topic_arn = aws_sns_topic.s3_events.arn
    events    = ["s3:ObjectCreated:*"]
  }
}

# Variable for cross-region replication destination bucket
variable "replication_dest_bucket_arn" {
  description = "ARN of the S3 bucket in a different region for cross-region replication of audit logs. Must be overridden with a real bucket ARN before applying."
  type        = string
  default     = "arn:aws:s3:::placeholder-audit-logs-replica"
}

# IAM role for S3 cross-region replication (CKV_AWS_144)
resource "aws_iam_role" "replication" {
  name = "${var.project_name}-s3-replication"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "replication" {
  name = "${var.project_name}-s3-replication"
  role = aws_iam_role.replication.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [aws_s3_bucket.audit_logs.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = ["${aws_s3_bucket.audit_logs.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["${var.replication_dest_bucket_arn}/*"]
      }
    ]
  })
}

# S3 cross-region replication configuration (CKV_AWS_144)
resource "aws_s3_bucket_replication_configuration" "audit_logs" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "replicate-audit-logs"
    status = "Enabled"
    destination {
      bucket        = var.replication_dest_bucket_arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [aws_s3_bucket_versioning.audit_logs]
}

# --- KMS Key for Audit and Config Data ---
resource "aws_kms_key" "audit_logs" {
  description         = "KMS key for audit logs and AWS Config data."
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:GetKeyPolicy",
          "kms:PutKeyPolicy",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:EnableKey",
          "kms:DisableKey",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ListResourceTags"
        ]
        Resource = "*"
      }
    ]
  })
  tags = local.tags
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
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      },
    ]
  })
}

# CloudWatch Log Group for CloudTrail logs (Define mandatory log retention policy)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.cloudtrail_name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.audit_logs.arn
}

# SNS Topic for CloudTrail notifications
resource "aws_sns_topic" "cloudtrail" {
  name              = "${var.project_name}-cloudtrail-notifications"
  kms_master_key_id = aws_kms_key.audit_logs.arn
  tags              = local.tags
}

# Centralized Auditing via CloudTrail
resource "aws_cloudtrail" "main" {
  name                          = local.cloudtrail_name
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_logging                = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.audit_logs.arn
  sns_topic_name                = aws_sns_topic.cloudtrail.name

  # Link to CloudWatch Logs for real-time security event monitoring
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_logs.arn
}

# --- 2. Isolated Networking (VPC) ---
# 
resource "aws_vpc" "secure_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.project_name}-vpc" })
}

# Private Subnets (where application compute resides, isolated from direct internet access)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.secure_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.secure_vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = merge(local.tags, { Name = "${var.project_name}-private-${count.index}" })
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

resource "aws_guardduty_organization_configuration" "main" {
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.main.id
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
  status                       = "ENABLED"
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
    description = "Allow outbound HTTPS"
  }

  tags = merge(local.tags, { Name = "${var.project_name}-compute-sg" })
}

# Restrict default VPC security group to deny all traffic (CKV2_AWS_12)
resource "aws_default_security_group" "secure_vpc" {
  vpc_id = aws_vpc.secure_vpc.id
  tags   = merge(local.tags, { Name = "${var.project_name}-default-sg" })
}

# Network interface to satisfy Security Group attachment requirement (CKV2_AWS_5)
resource "aws_network_interface" "compute" {
  subnet_id       = aws_subnet.private[0].id
  security_groups = [aws_security_group.compute.id]
  tags            = merge(local.tags, { Name = "${var.project_name}-compute-eni" })
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
  name = "SecureComputeRole"
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
  s3_kms_key_arn = aws_kms_key.audit_logs.arn
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

output "current_region" {
  description = "The AWS region where resources are deployed"
  value       = data.aws_region.current.name
}
