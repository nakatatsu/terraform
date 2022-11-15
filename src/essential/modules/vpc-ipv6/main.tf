/**
IPv4 VPC

- 1vpc, 3az * public/private のSubnet。
- Natゲートウェイを使わずEgress-Only Internet Gatewayを利用する。

公式リファレンスに"IPv6 CIDR ブロックと VPC の関連付けを解除できます。VPC から IPv6 CIDR ブロックの関連付けを解除すると、IPv6 CIDR ブロックと VPC を後で再び関連付けた場合に同じ CIDR を受け取ることは期待できません。"
とあるため、時折見られるIPアドレス直接の管理はすべきでない。作り直したくなった時に一から設定しなおしになるためだ。
(https://docs.aws.amazon.com/ja_jp/vpc/latest/userguide/configure-your-vpc.html#vpc-sizing-ipv6)

*/

resource "aws_vpc" "main" {
  assign_generated_ipv6_cidr_block = true
  cidr_block                       = var.vpc.cidr_block
  enable_dns_hostnames             = "true"
  enable_dns_support               = "true"
  instance_tenancy                 = "default"
  # ipv6_cidr_block                      = var.vpc.ipv6_cidr_block # "2406:da14:a82:9d00::/56"
  # ipv6_netmask_length                  = "0"
  #  ipv6_cidr_block_network_border_group = "ap-northeast-1"

  tags = {
    Name = "${var.environment.name}-vpc"
  }
}


resource "aws_subnet" "subnet" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet }

  vpc_id                                         = aws_vpc.main.id
  ipv6_native                                    = true
  ipv6_cidr_block                                = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.netnum)
  private_dns_hostname_type_on_launch            = "resource-name"
  availability_zone                              = "${var.environment.region}${each.value.az}"
  assign_ipv6_address_on_creation                = true
  enable_resource_name_dns_aaaa_record_on_launch = true

  tags = {
    Name = "${var.environment.name}-${var.environment.region}${each.value.az}-${each.value.type}"
  }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment.name}-${var.environment.region}"
  }
}

resource "aws_egress_only_internet_gateway" "egress" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment.name}-${var.environment.region}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment.name}-${var.environment.region}-public"
  }
}

resource "aws_route" "public" {
  destination_ipv6_cidr_block = "::/0"
  route_table_id              = aws_route_table.public.id
  gateway_id                  = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_route" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "public" }

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.subnet["${each.value.az}_${each.value.type}"].id
}

resource "aws_route_table" "private" {
  vpc_id   = aws_vpc.main.id
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "private" }

  tags = {
    Name = "${var.environment.name}-${var.environment.region}${each.value.az}-private"
  }
}

resource "aws_route" "private" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "private" }

  destination_ipv6_cidr_block = "::/0"
  route_table_id              = aws_route_table.private["${each.value.az}_${each.value.type}"].id
  egress_only_gateway_id      = aws_egress_only_internet_gateway.egress.id
}

resource "aws_route_table_association" "private_route" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "private" }

  subnet_id      = aws_subnet.subnet["${each.value.az}_${each.value.type}"].id
  route_table_id = aws_route_table.private["${each.value.az}_${each.value.type}"].id
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.environment.region}.s3"
  policy       = file("${path.module}/templates/s3_endpoint_gateway_policy.json")

  tags = {
    Name = "${var.environment.name}-${var.environment.region}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3_endpoint" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "private" }

  vpc_endpoint_id = aws_vpc_endpoint.s3_endpoint.id
  route_table_id  = aws_route_table.private["${each.value.az}_${each.value.type}"].id
}

