output "ingress_rule" {
  description = "The MinIO ingress rule for Cloudflare Zero Trust Tunnel"
  value = {
    hostname = "minio.${var.domain_base}"
    service  = "http://host:9000"
  }
}

output "service_token_id" {
  description = "The service token client ID for accessing MinIO"
  value       = data.cloudflare_zero_trust_access_service_token.minio_token.client_id
  sensitive   = false
}

output "access_url" {
  description = "The URL to access MinIO"
  value       = "https://minio.${var.domain_base}"
}
