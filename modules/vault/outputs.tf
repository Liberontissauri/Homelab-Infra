output "vault_network" {
  description = "The Docker network for OpenBao"
  value       = docker_network.vault_network
}

output "vault_network_name" {
  description = "The name of the Docker network for OpenBao"
  value       = docker_network.vault_network.name
}

output "openbao_container_id" {
  description = "Docker container ID of OpenBao"
  value       = docker_container.openbao.id
}
