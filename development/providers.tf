provider "aws" {
  default_tags {
    tags = {
      Service     = "personal-website"
      Environment = var.env
    }
  }
}
