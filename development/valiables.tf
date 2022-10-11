variable "env" {}

variable "region" {}

variable "administrative_bucket" {}

variable "administrator_mail_address" {}

variable "send_mail_s3_key" {
  type    = string
  default = "lambda_python_default.zip"
}

variable "service_name" {}

variable "service_url" {}

variable "mail_reply_title" {}



