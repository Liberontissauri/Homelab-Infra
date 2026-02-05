terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "ssh://root@${var.homelab_ip}:22"
}

# MinIO for Terraform state storage
module "minio" {
  source = "../../modules/minio"
  providers = {
    docker = docker
  }
  minio_root_user     = "admin"
  minio_root_password = var.minio_root_password
}

# OpenBao (Vault) for secrets management
module "vault" {
  source = "../../modules/vault"
  providers = {
    docker = docker
  }
}
