resource "aws_ses_domain_identity" "site_domain" {
  domain = "${var.domain}"
}
