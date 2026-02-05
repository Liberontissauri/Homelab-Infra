variable "homelab_ip" {
  type        = string
  description = "IP address of the homelab server"
}

variable "minio_root_password" {
  type        = string
  description = "Root password for MinIO"
  sensitive   = true
}
