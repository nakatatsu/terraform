variable "environment" {}

variable "vpc" {}

variable "subnets" {
  default = [
    {
      netnum = 1
      az     = "a"
      type   = "public"
    },
    {
      netnum = 2
      az     = "c"
      type   = "public"
    },
    {
      netnum = 3
      az     = "d"
      type   = "public"
    },
    {
      netnum = 4
      az     = "a"
      type   = "private"
    },
    {
      netnum = 5
      az     = "c"
      type   = "private"
    },
    {
      netnum = 6
      az     = "d"
      type   = "private"
    },
  ]
}
