provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Service     = "personal-website"
      Environment = var.environment.name
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us_east_1"
}
