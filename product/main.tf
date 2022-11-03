terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.33.0"
    }
  }
  backend "s3" {
    bucket = "product-general-tricrow"
    key    = "terraform/product.tfstate"
    region = "ap-northeast-1"
  }
}

module "personal_website_common" {
  source          = "../modules/personal-website-common"
  environment     = var.environment
  log_bucket_name = "${var.environment.name}-log-${var.environment.s3_suffix}"
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

# API Gatewayのステージ機能は使わず、サブドメインを分ける想定。
module "api_gateway_custom_domain" {
  source                     = "../modules/api-gateway-custom-domain"
  domain_name                = "api.${var.route53.domain}"
  route53                    = var.route53
  acm_certificate_validation = { certificate_arn : var.acm.ap_northeast_1 }
}

module "personal_website_backend" {
  source = "../modules/personal-website-backend"

  environment = var.environment
  common      = var.personal_website_backend.common
}

# productのみで実施
module "github_actions" {
  source = "../modules/github-actions"

  environment = var.environment
  common      = var.personal_website_backend.common

}

