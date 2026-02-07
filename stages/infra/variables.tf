# --- Non Sensitive --- #

variable "homelab_ip" {
  type = string
}
variable "ssh_port_homelab" {
  type = string
}

variable "vps_ip" {
  type = string
}

variable "ssh_port_vps" {
  type = string
}

variable "tf_state_bucket_name" {
  type    = string
}

variable "domain_base" {
  type = string
}

variable "access_service_token_name" {
  type = string
}

# --- Sensitive --- #

variable "minio_root_password" {
  type      = string
}

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

variable "docker_registry_admin_password" {
  type = string
}
