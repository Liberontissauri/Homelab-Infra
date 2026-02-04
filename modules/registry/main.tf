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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Docker network for registry
resource "docker_network" "registry_network" {
  name = "registry_network"
}

# Persistent volumes for registry data and auth
resource "docker_volume" "registry_data" {
  name = "registry_data"
}

resource "docker_volume" "registry_auth" {
  name = "registry_auth"
}

# Docker Registry Container
resource "docker_container" "registry" {
  name    = "registry"
  image   = "registry:3"
  restart = "unless-stopped"
  networks_advanced { name = var.network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.registry_data.name
    container_path = "/var/lib/registry"
  }

  volumes {
    volume_name    = docker_volume.registry_auth.name
    container_path = "/auth"
  }

  ports {
    internal = 5000
    external = var.registry_port
  }

  env = [
    "REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry",
    "REGISTRY_STORAGE_DELETE_ENABLED=true",
    "REGISTRY_AUTH=htpasswd",
    "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm",
    "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd"
  ]

  healthcheck {
    test     = ["CMD", "wget", "--spider", "-q", "http://localhost:5000/v2/"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# Create htpasswd file on remote Docker host if authentication is enabled
resource "null_resource" "registry_auth" {
  triggers = {
    username     = var.auth_username
    password     = var.auth_password
    container_id = docker_container.registry.id
  }

  connection {
    type = "ssh"
    host = split("@", var.docker_host)[1]
    user = split("@", var.docker_host)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "docker exec ${docker_container.registry.name} sh -c 'apk add --no-cache apache2-utils && htpasswd -Bbn \"${var.auth_username}\" \"${var.auth_password}\" > /auth/htpasswd'"
    ]
  }

  depends_on = [docker_container.registry]
}

# --- Registry DNS ---
# Create the DNS record pointing to the tunnel
resource "cloudflare_dns_record" "registry_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "registry"
  ttl     = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
