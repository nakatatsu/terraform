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
    key    = "terraform/essential/develop-ipv6.tfstate"
    region = "ap-northeast-1"
  }
}

module "essential_vpc" {
  source = "../modules/vpc-ipv6"

  # vpcはIPv4指定がいる
  vpc = {
    "cidr_block" = "10.0.0.0/16"
  }
  environment = var.environment
}
