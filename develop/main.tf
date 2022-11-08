terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.33.0"
    }
  }
  backend "s3" {
    bucket = "develop-general-tricrow"
    key    = "terraform/develop.tfstate"
    region = "ap-northeast-1"
  }
}

module "personal_website_common" {
  source          = "../modules/personal-website-common"
  environment     = var.environment
  log_bucket_name = "${var.environment.name}-log-${var.environment.s3_suffix}"
  github          = var.github
}

module "personal_website_frontend" {
  source                    = "../modules/personal-website-frontend"
  environment               = var.environment
  personal_website_frontend = var.personal_website_frontend
  public_bucket_name        = "${var.environment.name}-public-${var.environment.s3_suffix}"
  log_bucket                = module.personal_website_common.log_bucket
  acm                       = var.acm
  route53                   = var.route53
}
module "api_gateway_custom_domain" {
  source                     = "../modules/api-gateway-custom-domain"
  domain_name                = "${var.environment.name}-api.${var.route53.domain}"
  route53                    = var.route53
  acm_certificate_validation = { certificate_arn : var.acm.ap_northeast_1 }
}

module "personal_website_backend" {
  source = "../modules/personal-website-backend"

  environment              = var.environment
  personal_website_backend = var.personal_website_backend
}

module "direct_deploy" {
  source = "../modules/direct-deploy"

  environment = var.environment
}
