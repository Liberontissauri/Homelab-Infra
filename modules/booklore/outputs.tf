output "ingress_rule" {
    value = {
        hostname = "books.${var.domain_base}"
        service  = "http://booklore:6060"
    }
}