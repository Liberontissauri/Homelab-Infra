variable "homelab_ip" {
  type = string
}
variable "vps_ip" {
  type = string
}
variable "minio_root_password" {
  type      = string
}
variable "tf_state_bucket_name" {
  type    = string
}

# --- Cloudflare --- #

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "domain_base" {
  type = string
}

variable "docker_registry_admin_password" {
  type = string
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
  description = "GitHub OAuth App client ID for Woodpecker"
}

variable "github_client_secret" {
  type        = string
  description = "GitHub OAuth App client secret for Woodpecker"
  sensitive   = true
}