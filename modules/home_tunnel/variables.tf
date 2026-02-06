variable "domain_base" {
  description = "The base domain for the homelab services"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_tunnel_id" {
  description = "The Cloudflare Tunnel ID"
  type        = string
}

variable "homelab_ip" {
  description = "The IP address of the homelab host"
  type        = string
}

variable "access_service_token_name" {
  description = "The name of the existing Cloudflare Access service token"
  type        = string
}
variable "cloudflare_account_id" {
  description = "The Cloudflare Account ID"
  type        = string
}