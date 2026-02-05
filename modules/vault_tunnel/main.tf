terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.16"
    }
  }
}

# --- OpenBao DNS ---
# Create the DNS record pointing to the tunnel
resource "cloudflare_dns_record" "vault_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "vault"
  ttl     = 1
  content = "${var.cloudflare_tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
