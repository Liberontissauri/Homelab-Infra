output "ingress_rule" {
    description = "The Affine ingress rule for Cloudflare Zero Trust Tunnel"
    value       = {
        hostname = "affine.${var.domain_base}"
        service  = "http://affine:3010"
    }
}