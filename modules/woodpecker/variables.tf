variable "domain_base" {
  type        = string
  description = "Base domain for service (e.g., example.com)"
}

variable "docker_network_name" {
  type        = string
  description = "Name of the shared Docker network"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for DNS records"
}

variable "cloudflare_tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID for ingress routing"
}

variable "woodpecker_admin_user" {
  type        = string
  description = "Woodpecker admin username"
}

variable "woodpecker_agent_secret" {
  type        = string
  description = "Shared secret for agent authentication"
  sensitive   = true
}

variable "github_client_id" {
  type        = string
  description = "GitHub OAuth App client ID"
}

variable "github_client_secret" {
  type        = string
  description = "GitHub OAuth App client secret"
  sensitive   = true
}
