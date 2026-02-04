output "ingress_rule" {
  description = "The Woodpecker CI ingress rule for Cloudflare Zero Trust Tunnel"
  value = {
    hostname = "ci.${var.domain_base}"
    service  = "http://woodpecker_server:8000"
  }
}

output "agent_secret" {
  description = "Woodpecker agent secret for connecting additional agents"
  value       = var.woodpecker_agent_secret
  sensitive   = true
}
