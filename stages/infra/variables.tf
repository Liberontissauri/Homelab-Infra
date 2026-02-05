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
