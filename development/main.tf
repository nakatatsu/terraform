terraform {
  required_version = "~> 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.33.0"
    }
  }
  backend "s3" {
    bucket = "development-terraform-20221006"
    key    = "development"
    region = "ap-northeast-1"
  }
}

module "personal-website-backend" {
  source = "../modules/personal-website-backend"

  env                        = var.env
  region                     = var.region
  administrative_bucket      = var.administrative_bucket
  send_mail_s3_key           = var.send_mail_s3_key
  administrator_mail_address = var.administrator_mail_address
  service_name               = var.service_name
  service_url                = var.service_url
  mail_reply_title           = var.mail_reply_title
}
