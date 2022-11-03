# https://developer.hashicorp.com/terraform/language/modules/develop/providers
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_acm_certificate" "ssl_certificate" {
  domain_name       = "*.${var.route53.domain}"
  validation_method = "DNS"
}

resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for v in aws_acm_certificate.ssl_certificate.domain_validation_options : v.domain_name => {
      name   = v.resource_record_name
      record = v.resource_record_value
      type   = v.resource_record_type
    }
  }

  /* レコードを上書きしている。
  複数リージョンで同じ設定を使いまわすと同じレコードになるらしく――必ずなのかはわからないが――、そのままではエラーになる。
  そこで上書きしている。無駄な上書きをかけるのは読解を阻害して好ましくないが、回避しようとするとかえってコードが見づらくなると判断。
  */
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  zone_id         = var.route53.zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "ssl_certificate" {
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for v in aws_route53_record.certificate_validation : v.fqdn]
}
