# Associate existing WAF WebACL with Application Load Balancer
resource "aws_wafv2_web_acl_association" "alb" {
  count = var.waf_web_acl_arn != null ? 1 : 0

  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_web_acl_arn
}
