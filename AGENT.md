# AGENT.md - Homelab Infrastructure Guide

## Project Overview

This is a Terraform-based homelab infrastructure that manages Docker containers across multiple hosts (homelab server and VPS) with Cloudflare Zero Trust Tunnel for secure external access. The infrastructure uses MinIO for remote state management and follows a modular architecture pattern.

### Architecture Components

- **Terraform Modules**: Reusable service definitions in `modules/`
- **Stages**: Three deployment stages (`init`, `tfstate`, `infra`) deployed in sequence
- **Networking**: All services run on a shared Docker network (`homelab_internal`)
- **Ingress**: Cloudflare Zero Trust Tunnel with centralized routing configuration
- **State Management**: S3-compatible backend using self-hosted MinIO

### Infrastructure Layout

```
homelab_infra/
├── modules/              # Reusable Terraform modules for services
|   ├── others...         # Other service modules
│   ├── minio/           # Example: Simple single-container service
│   ├── registry/        # Example: Docker registry with auth
│   └── bucket/          # Example: MinIO bucket creation utility
├── stages/
│   ├── init/            # Stage 1: Deploy MinIO for state storage
│   ├── tfstate/         # Stage 2: Create S3 bucket for Terraform state
│   └── infra/           # Stage 3: Deploy all services with S3 backend
└── README.md
```

### Deployment Order

1. **stages/init** - Deploys MinIO instance (local tfstate)
2. **stages/tfstate** - Creates Terraform state bucket (local tfstate)
3. **stages/infra** - Deploys all service modules (S3 remote state)

## Module Architecture Patterns

### Remote plan execution

The apply of a stage should always be independent from the local machine. To achieve this avoid using local-exec provisioners or any resource that depends on local files or state, including when making use of bind mounts for example.

### Standard Module Structure

Every module in `modules/<service-name>/` should contain:

```
modules/<service-name>/
├── main.tf          # Service logic: resources, containers, volumes
├── variables.tf     # Input variables (standardized set)
├── outputs.tf       # Output values (must include ingress_rule if public-facing)
```

### Required Providers

Most service modules require these providers:

```terraform
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
```

Add `random` provider if generating passwords or secrets.

### Standard Input Variables

All public-facing service modules **MUST** accept these variables:

```terraform
variable "domain_base" {
  type        = string
  description = "Base domain for service (e.g., example.com)"
}

variable "docker_network_name" {
  type        = string
  description = "Name of the shared Docker network"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for DNS records"
}

variable "cloudflare_tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID for ingress routing"
}
```

Add service-specific variables as needed (ports, credentials, paths, etc.).

### Required Outputs

Public-facing service modules that create a cloudflare tunnel **MUST** export an `ingress_rule` output:

```terraform
output "ingress_rule" {
  description = "Cloudflare Tunnel ingress rule for <service-name>"
  value = {
    hostname = "<subdomain>.${var.domain_base}"
    service  = "http://<container-name>:<port>"
  }
}
```

This output is consumed by `stages/infra/main.tf` for centralized tunnel routing.

## Rules for Adding New Modules

### 1. Create Module Directory Structure

```bash
mkdir -p modules/<service-name>
touch modules/<service-name>/{main.tf,variables.tf,outputs.tf}
```

### 2. Define Resources in main.tf

Follow this pattern:

```terraform
# --- <Service Name> Logic ---
terraform {
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.16" }
  }
}

# Generate secrets with random_password if needed
resource "random_password" "<service>_password" {
  length  = 32
  special = false
}

# Create Docker volumes for persistent data
resource "docker_volume" "<service>_data" {
  name = "<service>_data"
}

# Deploy containers
resource "docker_container" "<service>" {
  name    = "<service>"
  image   = "<image:tag>"
  restart = "unless-stopped"
  networks_advanced { name = var.docker_network_name }

  log_driver = "json-file"
  log_opts = {
    "max-size" = "10m"
    "max-file" = "3"
  }

  volumes {
    volume_name    = docker_volume.<service>_data.name
    container_path = "/data"
  }

  env = [
    "VARIABLE=value"
  ]
}

# Create DNS record for public access
resource "cloudflare_dns_record" "<service>_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "<subdomain>"
  ttl     = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
```

### 3. Define Standard Variables (variables.tf)

```terraform
variable "domain_base" {
  type = string
}

variable "docker_network_name" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_tunnel_id" {
  type = string
}

# Add service-specific variables here
```

### 4. Export Ingress Rule (outputs.tf)

```terraform
output "ingress_rule" {
  description = "The <service> ingress rule for Cloudflare Zero Trust Tunnel"
  value = {
    hostname = "<subdomain>.${var.domain_base}"
    service  = "http://<container-name>:<port>"
  }
}
```

### 5. Register Module in stages/infra/main.tf

Add module declaration:

```terraform
module "<service>" {
  source = "../../modules/<service>"
  providers = {
    docker     = docker
    cloudflare = cloudflare
  }
  docker_network_name  = docker_network.homelab_network.name
  domain_base          = var.domain_base
  cloudflare_zone_id   = var.cloudflare_zone_id
  cloudflare_tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.homelab_tunnel.id
}
```

### 6. Add Ingress Rule to Tunnel Configuration

Update the `cloudflare_zero_trust_tunnel_cloudflared_config` resource in `stages/infra/main.tf`:

```terraform
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
          module.<service>.ingress_rule,  # ADD THIS LINE
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
```

## Best Practices

### Container Configuration

1. **Always set restart policy**: Use `restart = "unless-stopped"` for services, `restart = "no"` for one-time jobs
2. **Use shared network**: All containers should join `var.docker_network_name`
3. **Configure logging**: Use json-file driver with rotation (`max-size: 10m`, `max-file: 3`)
4. **Name volumes explicitly**: Use `docker_volume` resources with descriptive names
5. **Add health checks**: Include healthcheck blocks for databases and critical services

### Security

1. **Generate random passwords**: Use `random_password` resource for all credentials
2. **Never hardcode secrets**: Always use variables or generated values
3. **Set appropriate user/group IDs**: Use PUID/PGID environment variables where supported

### Dependencies

1. **Use depends_on**: Explicitly declare container dependencies (e.g., app depends on database)
2. **Wait for health checks**: Leverage healthcheck blocks to ensure services are ready

### Multi-Container Services

For services with multiple containers (app + database):

1. Create separate `docker_container` resources for each component
2. Use `depends_on` to establish startup order
3. Share credentials via environment variables using references
4. Use Docker network for internal communication (no port mapping needed)

Example pattern (from booklore):
```terraform
resource "docker_container" "service_db" { ... }

resource "docker_container" "service_app" {
  depends_on = [docker_container.service_db]
  env = [
    "DATABASE_URL=jdbc:mariadb://service_db:3306/dbname",
    "DATABASE_PASSWORD=${random_password.service_db_password.result}"
  ]
}
```

## Advanced Patterns

### Multi-Host Deployment

For services spanning homelab and VPS (see `rathole` module):

1. Use provider aliases in `stages/infra/main.tf`:
   ```terraform
   provider "docker" { alias = "vps", host = "ssh://root@${var.vps_ip}:22" }
   ```

2. Pass multiple providers to module:
   ```terraform
   module "rathole" {
     providers = {
       docker     = docker
       docker.vps = docker.vps
     }
   }
   ```

3. Reference providers explicitly in module:
   ```terraform
   resource "docker_container" "server" {
     provider = docker.vps
   }
   ```

### Non-Public Services

If a service doesn't need external access:

1. Omit Cloudflare DNS record
2. Omit `ingress_rule` output
3. Don't add to tunnel configuration
4. Still join the shared Docker network for internal access

### Template Files

For services requiring configuration files (see `rathole`):

1. Create `modules/<service>/config/` directory
2. Use `.tpl` suffix for templates
3. Render with `templatefile()` function


## Migration and Updates

### Updating Module Images

Simply change the `image` value in `main.tf` and apply:
```terraform
resource "docker_container" "service" {
  image = "service:new-version"
}
```
