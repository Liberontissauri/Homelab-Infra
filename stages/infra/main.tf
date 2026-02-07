terraform {
    backend "s3" {
        bucket = var.tf_state_bucket_name
        key    = "homelab/terraform.tfstate"
        
        endpoints = {
            s3 = "http://${var.homelab_ip}:9000"
        }
        
        region = "main"
        skip_credentials_validation = true
        skip_requesting_account_id = true
        skip_metadata_api_check = true
        skip_region_validation = true
        use_path_style = true
        access_key = "admin"
        secret_key = "${var.minio_root_password}"
        use_lockfile = true
    }

    required_providers {
        cloudflare = {
            source  = "cloudflare/cloudflare"
            version = "~> 5.16"
        }
        docker = {
            source  = "kreuzwerker/docker"
            version = "~> 3.0"
        }
        random = {
            source = "hashicorp/random"
        }
    }
}

provider "docker" {
  host = "ssh://root@${var.homelab_ip}:${var.ssh_port_homelab}"
}

provider "docker" {
  alias = "vps"
  host  = "ssh://root@${var.vps_ip}:${var.ssh_port_vps}"
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# --- Shared Infrastructure ---
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "docker_network" "homelab_network" {
  name = "homelab_internal"
}

# Fetch the vault network created by the vault stage
data "docker_network" "vault_network" {
  name = "vault_network"
}

# The Global Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "homelab-gateway"
  tunnel_secret = random_id.tunnel_secret.b64_std 
  
}

# Fetch the tunnel token
data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab_tunnel_token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
}

# The actual connector container that runs the tunnel
resource "docker_container" "cloudflared" {
  name  = "cloudflared_connector"
  image = "cloudflare/cloudflared:latest"
  restart = "always"
  networks_advanced { name = docker_network.homelab_network.name }
  networks_advanced { name = data.docker_network.vault_network.name }
  
  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }
  
  host {
    host = "host"
    ip   = "host-gateway"
  }
  
  command = ["tunnel", "--no-autoupdate", "run", "--token", data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab_tunnel_token.token]
}

module "affine" {
    source = "../../modules/affine"
    providers = {
        docker = docker
        cloudflare = cloudflare
    }
    docker_network_name   = docker_network.homelab_network.name
    domain_base           = var.domain_base
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
}

module "booklore" {
    source = "../../modules/booklore"
    providers = {
        docker = docker
        cloudflare = cloudflare
    }
    docker_network_name   = docker_network.homelab_network.name
    domain_base           = var.domain_base
    cloudflare_zone_id    = var.cloudflare_zone_id
    cloudflare_tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
}

module "rathole" {
    source = "../../modules/rathole"
    providers = {
        docker = docker
        docker.vps = docker.vps
        cloudflare = cloudflare
    }
    domain_base = var.domain_base
    docker_network_name   = docker_network.homelab_network.name
    vps_ip                = var.vps_ip
    cloudflare_zone_id    = var.cloudflare_zone_id
}

module "registry" {
    source = "../../modules/registry"
    providers = {
        docker = docker
        cloudflare = cloudflare
    }
    domain_base           = var.domain_base
    cloudflare_tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
    cloudflare_zone_id    = var.cloudflare_zone_id
    docker_host = "root@${var.homelab_ip}"
    network_name = docker_network.homelab_network.name
    auth_password = var.docker_registry_admin_password
}

module "vault_tunnel" {
    source = "../../modules/vault_tunnel"
    providers = {
        cloudflare = cloudflare
    }
    domain_base           = var.domain_base
    cloudflare_tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
    cloudflare_zone_id    = var.cloudflare_zone_id
    vault_network_name    = data.docker_network.vault_network.name
}

module "home_tunnel" {
    source = "../../modules/home_tunnel"
    providers = {
        cloudflare = cloudflare
    }
    domain_base           = var.domain_base
    cloudflare_account_id = var.cloudflare_account_id
    cloudflare_tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
    cloudflare_zone_id    = var.cloudflare_zone_id
    access_service_token_name = var.access_service_token_name
    homelab_ip            = var.homelab_ip
}

module "minio_tunnel" {
  source = "../../modules/minio_tunnel"
  providers = {
    cloudflare = cloudflare
  }
  domain_base           = var.domain_base
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
  cloudflare_zone_id    = var.cloudflare_zone_id
  access_service_token_name = var.access_service_token_name
}

# --- Tunnel Routing Configuration ---
# Centralized configuration for all services on the tunnel

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab_routing" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id

  config = {
    ingress = concat(
      [
        for rule in [
          module.affine.ingress_rule,
          module.booklore.ingress_rule,
          module.registry.ingress_rule,
          module.vault_tunnel.ingress_rule,
          module.home_tunnel.ingress_rule,
          module.minio_tunnel.ingress_rule,
        ] : {
          hostname = rule.hostname
          service  = rule.service
        }
      ],
      [
        {
          service = "http_status:404"
        }
      ]
    )
  }
}
