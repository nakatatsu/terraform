terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.33.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
  backend "s3" {
    bucket = "shared-general-tricrow"
    key    = "terraform/personal-website/shared.tfstate"
    region = "ap-northeast-1"
  }
}


module "ssl_certificate_us_east_1" {
  source      = "../modules/ssl-certificate"
  route53     = var.route53
  environment = var.environment

  providers = {
    aws = aws.us_east_1
  }
}


module "ssl_certificate" {
  source      = "../modules/ssl-certificate"
  route53     = var.route53
  environment = var.environment
}
