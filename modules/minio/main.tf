terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Docker network for MinIO
resource "docker_network" "minio_network" {
  name = "minio_network"
}

# Persistent volume for MinIO data
resource "docker_volume" "minio_data" {
  name = "minio_data"
}

# MinIO Server Container
resource "docker_container" "minio" {
  name    = "minio"
  image   = "minio/minio:latest"
  restart = "unless-stopped"
  networks_advanced { name = docker_network.minio_network.name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/data"
  }

  ports {
    internal = 9000
    external = 9000
  }

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    "MINIO_BROWSER=off"
  ]

  command = ["server", "/data", "--console-address", ":9001"]

  healthcheck {
    test     = ["CMD", "mc", "ready", "local"]
    interval = "30s"
    timeout  = "20s"
    retries  = 3
  }
}
