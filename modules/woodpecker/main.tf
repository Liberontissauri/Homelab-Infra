# --- Woodpecker CI Service Logic ---
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

# Volumes for persistent data
resource "docker_volume" "woodpecker_server_data" {
  name = "woodpecker_server_data"
}

# Woodpecker Server
resource "docker_container" "woodpecker_server" {
  name    = "woodpecker_server"
  image   = "woodpeckerci/woodpecker-server:v3.13.0"
  restart = "unless-stopped"
  user    = "root"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.woodpecker_server_data.name
    container_path = "/var/lib/woodpecker"
  }

  env = [
    "WOODPECKER_OPEN=false",
    "WOODPECKER_HOST=https://ci.${var.domain_base}",
    "WOODPECKER_AGENT_SECRET=${var.woodpecker_agent_secret}",
    "WOODPECKER_ADMIN=${var.woodpecker_admin_user}",
    "WOODPECKER_GITHUB=true",
    "WOODPECKER_GITHUB_CLIENT=${var.github_client_id}",
    "WOODPECKER_GITHUB_SECRET=${var.github_client_secret}",
    "WOODPECKER_GRPC_ADDR=:9000",
    "WOODPECKER_SERVER_ADDR=:8000"
  ]

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost:8000/healthz"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }
}

# Woodpecker Agent
resource "docker_container" "woodpecker_agent" {
  name    = "woodpecker_agent"
  image   = "woodpeckerci/woodpecker-agent:v3.13.0"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  depends_on = [docker_container.woodpecker_server]

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  env = [
    "WOODPECKER_SERVER=woodpecker_server:9000",
    "WOODPECKER_AGENT_SECRET=${var.woodpecker_agent_secret}",
    "WOODPECKER_MAX_WORKFLOWS=4",
    "WOODPECKER_BACKEND=docker"
  ]
}

# DNS Record for Woodpecker Server
resource "cloudflare_dns_record" "woodpecker_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "ci"
  ttl     = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
