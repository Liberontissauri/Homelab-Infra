terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
      configuration_aliases = [docker.vps]
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
  }
}

resource "random_password" "rathole_token" {
  length           = 16
  special          = false
  override_special = "_%@"
}

# Server Service

resource "docker_container" "rathole_server" {
    provider = docker.vps
    name    = "rathole_server"
    image   = "rapiz1/rathole:latest"
    restart = "unless-stopped"

    log_driver = "json-file"
    log_opts = {
      "max-size" = "10m"
      "max-file" = "3"
    }

    ports {
      internal = 2333
      external = 2333
    }
    ports {
      internal = 25565
      external = 25565
    }
    ports {
      internal = 25575
      external = 25575
    }

    upload {
        content = templatefile("${path.module}/config/server.toml.tpl", {
            rathole_token = random_password.rathole_token.result
        })
        file = "/etc/rathole/config.toml"
    }


    command = ["/etc/rathole/config.toml"]
}

# Client Service

resource "docker_container" "rathole_client" {
    name    = "rathole_client"
    image   = "rapiz1/rathole:latest"
    restart = "unless-stopped"
    networks_advanced { name = var.docker_network_name }

    log_driver = "json-file"
    log_opts = {
      "max-size" = "10m"
      "max-file" = "3"
    }

    upload {
        content = templatefile("${path.module}/config/client.toml.tpl", {
            rathole_token = random_password.rathole_token.result
            vps_ip = var.vps_ip
        })
        file = "/etc/rathole/config.toml"
    }

    command = ["/etc/rathole/config.toml"]
}

# --- Minecraft DNS ---
# Create DNS record pointing to VPS where Minecraft is exposed via rathole
resource "cloudflare_dns_record" "minecraft_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "minecraft"
  ttl = 1
  content = var.vps_ip
  type    = "A"
  proxied = false  # Must be false for Minecraft (non-HTTP traffic)
}