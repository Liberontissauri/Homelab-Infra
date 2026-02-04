output "registry_url" {
  description = "URL of the Docker registry"
  value       = "http://localhost:${var.registry_port}"
}

output "registry_container_id" {
  description = "Docker container ID of the registry"
  value       = docker_container.registry.id
}

output "registry_network_name" {
  description = "Docker network name for the registry"
  value       = docker_network.registry_network.name
}

output "registry_data_volume" {
  description = "Docker volume name for registry data"
  value       = docker_volume.registry_data.name
}

output "ingress_rule" {
    value = {
        hostname = "registry.${var.domain_base}"
        service  = "http://registry:${var.registry_port}"
    }
}