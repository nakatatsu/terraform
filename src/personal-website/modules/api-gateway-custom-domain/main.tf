resource "aws_api_gateway_domain_name" "original_domain" {
  domain_name              = var.domain_name
  regional_certificate_arn = var.acm_certificate_validation.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "api_gateway_alias" {
  name    = aws_api_gateway_domain_name.original_domain.domain_name
  type    = "A"
  zone_id = var.route53.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_api_gateway_domain_name.original_domain.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.original_domain.regional_zone_id
  }
}
