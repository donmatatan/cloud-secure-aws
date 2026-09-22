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

# Referenciamos el bucket S3 que creamos por AWS CLI
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

# 2. Configuración de CloudTrail apuntando al Bucket de Logs y a CloudWatch Logs
resource "aws_cloudtrail" "audit_trail" {
  name                           = "blue-wave-audit-trail"
  s3_bucket_name                 = data.aws_s3_bucket.logs_bucket.id
  include_global_service_events = true
  is_multi_region_trail          = false
  enable_logging                 = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_log_group.arn}:*"
  cloud_watch_logs_role_arn  = data.aws_iam_role.lab_role.arn

  depends_on = [aws_s3_bucket_policy.cloudtrail_s3_policy]

  tags = {
    Environment = "Bootcamp-Cloud"
    Project     = "Cloud Secure"
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# LECCIÓN 3: GOBERNANZA Y CUMPLIMIENTO (AWS Config)
# -----------------------------------------------------------------------------

# 1. Obtener el LabRole precreado por AWS Academy
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Regla 1: Validar que todos los buckets S3 tengan Bloqueo de Acceso Público
resource "aws_config_config_rule" "s3_bucket_public_read_prohibited" {
  name        = "s3-bucket-public-read-prohibited"
  description = "Evalua si los buckets S3 prohiben el acceso publico de lectura."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

# Regla 2: Validar que el cifrado en reposo esté habilitado en S3
resource "aws_config_config_rule" "s3_bucket_server_side_encryption_enabled" {
  name        = "s3-bucket-server-side-encryption-enabled"
  description = "Evalua si los buckets S3 tienen el cifrado en reposo habilitado."

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
}

# -----------------------------------------------------------------------------
# LECCIÓN 4: MONITOREO ACTIVO Y ALARMAS (CloudWatch & SNS)
# -----------------------------------------------------------------------------

# 1. Grupo de Logs en CloudWatch para recibir auditoría de CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail_log_group" {
  name              = "/aws/cloudtrail/blue-wave-audit-logs"
  retention_in_days = 7

  tags = {
    Environment = "Bootcamp-Cloud"
    Project     = "Cloud Secure"
    ManagedBy   = "Terraform"
  }
}

# 2. Tema de Notificación SNS para Alertas de Seguridad
resource "aws_sns_topic" "security_alerts" {
  name = "blue-wave-security-alerts"
}

# 3. Suscripción por Correo Electrónico al Tema SNS
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = "jairojohanjairojohan@gmail.com"
}

# -----------------------------------------------------------------------------
# FILTROS DE MÉTRICAS Y ALARMAS
# -----------------------------------------------------------------------------

# Filtro 1: Detectar llamadas denegadas en la API (AccessDenied / UnauthorizedOperation)
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  name           = "UnauthorizedApiCallsFilter"
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_log_group.name

  metric_transformation {
    name      = "UnauthorizedApiCallsCount"
    namespace = "BlueWave/Security"
    value     = "1"
  }
}

# Alarma 1: Disparar alerta si hay llamadas denegadas en la API
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls_alarm" {
  alarm_name          = "blue-wave-unauthorized-api-calls-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.unauthorized_api_calls.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.unauthorized_api_calls.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Esta alarma se dispara cuando se detectan intentos no autorizados o llamadas denegadas en la API de AWS."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}