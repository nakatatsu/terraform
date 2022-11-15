provider "aws" {
  default_tags {
    tags = {
      Service     = "essentical"
      Environment = var.environment.name
    }
  }
}
