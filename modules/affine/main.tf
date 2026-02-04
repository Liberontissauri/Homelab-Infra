# --- Affine Service Logic ---
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
  }
}

# Generate random credentials for PostgreSQL
resource "random_password" "affine_db_password" {
  length  = 32
  special = false
}

resource "random_password" "affine_db_user" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

# Volumes for persistent data
resource "docker_volume" "affine_postgres_data" {
  name = "affine_postgres_data"
}

resource "docker_volume" "affine_storage" {
  name = "affine_storage"
}

resource "docker_volume" "affine_config" {
  name = "affine_config"
}

# PostgreSQL Database with pgvector
resource "docker_container" "affine_postgres" {
  name    = "affine_postgres"
  image   = "pgvector/pgvector:pg16"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.affine_postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  env = [
    "POSTGRES_USER=${random_password.affine_db_user.result}",
    "POSTGRES_PASSWORD=${random_password.affine_db_password.result}",
    "POSTGRES_DB=affine",
    "POSTGRES_INITDB_ARGS=--data-checksums",
    "POSTGRES_HOST_AUTH_METHOD=trust"
  ]

  healthcheck {
    test     = ["CMD", "pg_isready", "-U", "${random_password.affine_db_user.result}", "-d", "affine"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# Redis Cache (ephemeral)
resource "docker_container" "affine_redis" {
  name    = "affine_redis"
  image   = "redis:latest"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  healthcheck {
    test     = ["CMD", "redis-cli", "--raw", "incr", "ping"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# Migration Job (runs once on initial deployment)
resource "docker_container" "affine_migration" {
  name    = "affine_migration"
  image   = "ghcr.io/toeverything/affine:stable"
  restart = "no"
  must_run = false
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.affine_storage.name
    container_path = "/root/.affine/storage"
  }

  volumes {
    volume_name    = docker_volume.affine_config.name
    container_path = "/root/.affine/config"
  }

  command = ["sh", "-c", "node ./scripts/self-host-predeploy.js"]

  env = [
    "REDIS_SERVER_HOST=affine_redis",
    "DATABASE_URL=postgres://${random_password.affine_db_user.result}:${random_password.affine_db_password.result}@affine_postgres:5432/affine",
    "AFFINE_INDEXER_ENABLED=false"
  ]

  depends_on = [
    docker_container.affine_postgres,
    docker_container.affine_redis
  ]
}

# Main Affine Application
resource "docker_container" "affine" {
  name    = "affine"
  image   = "ghcr.io/toeverything/affine:stable"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.affine_storage.name
    container_path = "/root/.affine/storage"
  }

  volumes {
    volume_name    = docker_volume.affine_config.name
    container_path = "/root/.affine/config"
  }

  env = [
    "REDIS_SERVER_HOST=affine_redis",
    "DATABASE_URL=postgres://${random_password.affine_db_user.result}:${random_password.affine_db_password.result}@affine_postgres:5432/affine",
    "AFFINE_INDEXER_ENABLED=false",
    "AFFINE_SERVER_HOST=0.0.0.0",
    "AFFINE_SERVER_PORT=3010"
  ]
}

# --- Affine DNS ---
# Create the DNS record pointing to the tunnel
resource "cloudflare_dns_record" "affine_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "affine"
  ttl = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
