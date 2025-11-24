# Route53 DNS record for custom domain (optional)
# Creates an A record that points to the Application Load Balancer

data "aws_route53_zone" "main" {
  count        = var.route53_zone_id != null ? 1 : 0
  zone_id      = var.route53_zone_id
  private_zone = false
}

resource "aws_route53_record" "n8n" {
  count   = var.route53_zone_id != null && var.route53_record_name != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.route53_record_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
