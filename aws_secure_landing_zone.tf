/*
  AWS Secure Reference Architecture / Landing Zone
  
  This conceptual Terraform code defines a foundational secure environment (Landing Zone) in AWS.
  It demonstrates:
  1. Isolated Networking (VPC with private subnets).
  2. Centralized Auditing (CloudTrail + S3 logging bucket).
  3. Secure Compute (EC2 with restrictive IAM Role and Security Group).
  4. Least Privilege IAM for the compute workload.
*/

# --- 1. Centralized Logging & Auditing ---

# Dedicated S3 bucket for storing all logs and audit trails (CloudTrail, VPC Flow Logs)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "staff-secure-audit-logs-${data.aws_caller_identity.current.account_id}"
  acl    = "log-delivery-write" # Required for AWS services to deliver logs
  
  # Mandatory Encryption and Deny public access
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  
  block_public_access {
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
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
  
  # Link to CloudWatch Logs for real-time security event monitoring
  cloud_watch_logs_group_arn    = aws_cloudwatch_log_group.cloudtrail.arn
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_logs.arn
}

# --- 2. Isolated Networking (VPC) ---
# 
resource "aws_vpc" "secure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "Secure-VPC" }
}

# Private Subnets (where application compute resides, isolated from direct internet access)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.secure_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.secure_vpc.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "Private-Subnet-${count.index}" }
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
      # Add logs:PutLogEvents for the application's specific log group
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

# --- Data Sources (required for configuration) ---
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
