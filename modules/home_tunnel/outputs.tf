output "ingress_rule" {
  description = "The ingress rule for the Cloudflare Tunnel"
  value = {
    hostname = "home.${var.domain_base}"
    service  = "ssh://host:22"
  }
}

output "service_token_id" {
  description = "The service token client ID for accessing the home portal"
  value       = data.cloudflare_zero_trust_access_service_token.home_token.client_id
  sensitive   = false
}

output "access_url" {
  description = "The URL to access the home portal"
  value       = "ssh://home.${var.domain_base}"
}
