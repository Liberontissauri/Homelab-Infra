terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
  }
}

# --- MinIO DNS ---
# Create the DNS record pointing to the tunnel
resource "cloudflare_dns_record" "minio_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "minio"
  ttl     = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

# --- Cloudflare Access Application ---
# This protects the MinIO subdomain with an access policy
resource "cloudflare_zero_trust_access_application" "minio_app" {
  zone_id          = var.cloudflare_zone_id
  name             = "MinIO"
  domain           = "minio.${var.domain_base}"
  type             = "self_hosted"
  session_duration = "24h"
  policies = [ {
    id = cloudflare_zero_trust_access_policy.minio_policy.id
    precedence = 1
  } ]
}

# --- Access Policy with Service Token ---
# Use an existing service token by name
data "cloudflare_zero_trust_access_service_token" "minio_token" {
  account_id = var.cloudflare_account_id
  filter = {
    name = var.access_service_token_name
  }
}

# Policy that requires the service token
resource "cloudflare_zero_trust_access_policy" "minio_policy" {
  account_id     = var.cloudflare_account_id
  name           = "Allow with Service Token"
  decision       = "non_identity"

  include = [ {
    service_token = {
      token_id = data.cloudflare_zero_trust_access_service_token.minio_token.id
    }
  } ]
}
