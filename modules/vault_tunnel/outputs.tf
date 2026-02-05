output "ingress_rule" {
  description = "The OpenBao ingress rule for Cloudflare Zero Trust Tunnel"
  value = {
    hostname = "vault.${var.domain_base}"
    service  = "http://openbao:8200"
  }
}
