# 1. Crear el bucket en la región us-east-1
aws s3api create-bucket --bucket blue-wave-secure-bucket-bw --region us-east-1

# 2. Configurar Cifrado en Reposo (AES256)
aws s3api put-bucket-encryption \
  --bucket blue-wave-secure-bucket-bw \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 3. Habilitar Bloqueo de Acceso Público
aws s3api put-public-access-block \
  --bucket blue-wave-secure-bucket-bw \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'

# 3. Configurar Control de Propiedad de Objetos a BucketOwnerEnforced (Desactiva ACLs)
aws s3api put-bucket-ownership-controls \
  --bucket blue-wave-secure-bucket-bw \
  --ownership-controls '{"Rules": [{"ObjectOwnership": "BucketOwnerEnforced"}]}'

# 4. Asignar Etiquetas (Tags) de Gobernanza
aws s3api put-bucket-tagging \
  --bucket blue-wave-secure-bucket-bw \
  --tagging '{"TagSet": [{"Key": "Environment", "Value": "Bootcamp-Cloud"}, {"Key": "Project", "Value": "Cloud Secure"}, {"Key": "ManagedBy", "Value": "Terraform"}]}'

# ===== Bucket para logs de cloudtrail =====


# 5. Crear el bucket de logs
aws s3api create-bucket --bucket blue-wave-cloudtrail-logs-bw --region us-east-1

# 6. Configurar Cifrado en Reposo (AES256)
aws s3api put-bucket-encryption \
  --bucket blue-wave-cloudtrail-logs-bw \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 7. Activar Bloqueo de Acceso Público
aws s3api put-public-access-block \
  --bucket blue-wave-cloudtrail-logs-bw \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'

# 8. Desactivar ACLs (BucketOwnerEnforced)
aws s3api put-bucket-ownership-controls \
  --bucket blue-wave-cloudtrail-logs-bw \
  --ownership-controls '{"Rules": [{"ObjectOwnership": "BucketOwnerEnforced"}]}'

# 9. Asignar Etiquetas (Tags)
aws s3api put-bucket-tagging \
  --bucket blue-wave-cloudtrail-logs-bw \
  --tagging '{"TagSet": [{"Key": "Environment", "Value": "Bootcamp-Cloud"}, {"Key": "Project", "Value": "Cloud Secure"}, {"Key": "ManagedBy", "Value": "Terraform"}]}'