terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Docker network for OpenBao
resource "docker_network" "vault_network" {
  name = "vault_network"
}

# Persistent volume for OpenBao data
resource "docker_volume" "openbao_data" {
  name = "openbao_data"
}

# Persistent volume for OpenBao logs
resource "docker_volume" "openbao_logs" {
  name = "openbao_logs"
}

# Fix permissions on volumes for OpenBao user (UID 100)
resource "docker_container" "openbao_permissions" {
  name    = "openbao_permissions_setup"
  image   = "alpine:latest"
  restart = "no"
  must_run = false
  
  volumes {
    volume_name    = docker_volume.openbao_data.name
    container_path = "/vault/file"
  }
  
  volumes {
    volume_name    = docker_volume.openbao_logs.name
    container_path = "/vault/logs"
  }
  
  command = ["sh", "-c", "chown -R 100:1000 /vault/file /vault/logs && chmod -R 755 /vault/file /vault/logs"]
  
  depends_on = [
    docker_volume.openbao_data,
    docker_volume.openbao_logs
  ]
}

# OpenBao Server Container
resource "docker_container" "openbao" {
  name    = "openbao"
  image   = "openbao/openbao:latest"
  restart = "unless-stopped"
  networks_advanced { name = docker_network.vault_network.name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.openbao_data.name
    container_path = "/vault/file"
  }

  volumes {
    volume_name    = docker_volume.openbao_logs.name
    container_path = "/vault/logs"
  }

  ports {
    internal = 8200
    external = 8200
  }

  # Upload OpenBao server configuration
  upload {
    content = <<-EOF
      ui = true
      
      storage "file" {
        path = "/vault/file"
      }
      
      listener "tcp" {
        address     = "0.0.0.0:8200"
        tls_disable = 1
      }
      
      api_addr = "http://0.0.0.0:8200"
    EOF
    file    = "/vault/config/config.hcl"
  }

  capabilities {
    add = ["IPC_LOCK"]
  }

  command = ["server", "-config=/vault/config/config.hcl"]

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost:8200/v1/sys/health?uninitcode=200&standbycode=200&sealedcode=200"]
    interval = "30s"
    timeout  = "20s"
    retries  = 3
  }
  
  depends_on = [
    docker_container.openbao_permissions
  ]
}
