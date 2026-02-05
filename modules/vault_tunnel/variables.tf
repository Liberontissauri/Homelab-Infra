variable "domain_base" {
  type        = string
  description = "Base domain for service (e.g., example.com)"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for DNS records"
}

variable "cloudflare_tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID for ingress routing"
}

variable "vault_network_name" {
  type        = string
  description = "Name of the vault Docker network (for documentation/reference)"
}
