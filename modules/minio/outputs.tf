output "minio_network" {
    description = "The Docker network for Minio"
    value       = docker_network.minio_network
}