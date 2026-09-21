terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Referenciamos el bucket S3 que creamos por AWS CLI para evitar llamadas prohibidas por la SCP
data "aws_s3_bucket" "secure_bucket" {
  bucket = "blue-wave-secure-bucket-bw"
}

# Bucket Dedicado para Logs de Audit (CloudTrail)
data "aws_s3_bucket" "logs_bucket" {
  bucket = "blue-wave-cloudtrail-logs-bw"
}


# -----------------------------------------------------------------------------
# LECCIÓN 2: AUDITORÍA DE EVENTOS (AWS CloudTrail)
# -----------------------------------------------------------------------------

# 1. Política aplicada al Bucket de Logs para permitir escritura de CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_s3_policy" {
  bucket = data.aws_s3_bucket.logs_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = data.aws_s3_bucket.logs_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${data.aws_s3_bucket.logs_bucket.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# 2. Configuración de CloudTrail apuntando al Bucket de Logs
resource "aws_cloudtrail" "audit_trail" {
  name                          = "blue-wave-audit-trail"
  s3_bucket_name                = data.aws_s3_bucket.logs_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_s3_policy]

  tags = {
    Environment = "Bootcamp-Cloud"
    Project     = "Cloud Secure"
    ManagedBy   = "Terraform"
  }
}