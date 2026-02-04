variable "registry_port" {
  description = "External port for the Docker registry"
  type        = number
  default     = 5000
}

variable "network_name" {
  description = "Docker network name for the registry"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for DNS records"
  type        = string
}

variable "cloudflare_tunnel_id" {
  description = "Cloudflare tunnel ID"
  type        = string
}

variable "domain_base" {
  description = "Base domain"
  type = string
}

variable "auth_username" {
  description = "Username for registry authentication"
  type        = string
  default     = "admin"
}

variable "auth_password" {
  description = "Password for registry authentication"
  type        = string
  sensitive   = true
  default     = ""
}

variable "docker_host" {
  description = "Docker host address for remote execution (e.g., root@192.168.1.100)"
  type        = string
}