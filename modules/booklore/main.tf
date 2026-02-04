# --- Booklore Service Logic ---
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

# Generate random credentials for MariaDB
resource "random_password" "booklore_db_password" {
  length  = 32
  special = false
}

resource "random_password" "booklore_db_root_password" {
  length  = 32
  special = false
}

# Volumes for persistent data
resource "docker_volume" "booklore_mariadb_config" {
  name = "booklore_mariadb_config"
}

resource "docker_volume" "booklore_data" {
  name = "booklore_data"
}

resource "docker_volume" "booklore_books" {
  name = "booklore_books"
}

resource "docker_volume" "booklore_bookdrop" {
  name = "booklore_bookdrop"
}

# MariaDB Database
resource "docker_container" "booklore_mariadb" {
  name    = "booklore_mariadb"
  image   = "lscr.io/linuxserver/mariadb:11.4.5"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.booklore_mariadb_config.name
    container_path = "/config"
  }

  env = [
    "PUID=1000",
    "PGID=1000",
    "TZ=Etc/UTC",
    "MYSQL_ROOT_PASSWORD=${random_password.booklore_db_root_password.result}",
    "MYSQL_DATABASE=booklore",
    "MYSQL_USER=booklore",
    "MYSQL_PASSWORD=${random_password.booklore_db_password.result}"
  ]

  healthcheck {
    test     = ["CMD", "mariadb-admin", "ping", "-h", "localhost"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }
}

# Booklore Application
resource "docker_container" "booklore" {
  name    = "booklore"
  image   = "booklore/booklore:latest"
  restart = "no"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.booklore_data.name
    container_path = "/app/data"
  }

  volumes {
    volume_name    = docker_volume.booklore_books.name
    container_path = "/books"
  }

  volumes {
    volume_name    = docker_volume.booklore_bookdrop.name
    container_path = "/bookdrop"
  }

  env = [
    "USER_ID=0",
    "GROUP_ID=0",
    "TZ=Etc/UTC",
    "DATABASE_URL=jdbc:mariadb://booklore_mariadb:3306/booklore",
    "DATABASE_USERNAME=booklore",
    "DATABASE_PASSWORD=${random_password.booklore_db_password.result}",
    "BOOKLORE_PORT=6060"
  ]

  depends_on = [
    docker_container.booklore_mariadb
  ]
}

# --- Booklore Ingress Rule ---
locals {
  booklore_ingress_rule = {
    hostname = "books.${var.domain_base}"
    service  = "http://booklore:6060"
  }
}

# Create the DNS record pointing to the tunnel
resource "cloudflare_dns_record" "booklore_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "books"
  ttl = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
