/**
IPv4 VPC

- 1vpc, 3az * public/private のSubnet。
- Natゲートウェイを1aにしか置かない設計。
*/

resource "aws_vpc" "main" {
  assign_generated_ipv6_cidr_block = "false"
  cidr_block                       = var.vpc.cidr_block
  enable_dns_hostnames             = "true"
  enable_dns_support               = "true"
  instance_tenancy                 = "default"

  tags = {
    Name = "${var.environment.name}-vpc"
  }
}


resource "aws_subnet" "subnet" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet }

  vpc_id                              = aws_vpc.main.id
  cidr_block                          = cidrsubnet(aws_vpc.main.cidr_block, 4, each.value.netnum)
  private_dns_hostname_type_on_launch = "resource-name"
  availability_zone                   = "${var.environment.region}${each.value.az}"
  map_public_ip_on_launch             = each.value.type == "public" ? true : false

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

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment.name}-${var.environment.region}-public"
  }
}

resource "aws_route" "public" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_route" {
  for_each = { for subnet in var.subnets : "${subnet.az}_${subnet.type}" => subnet if subnet.type == "public" }

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.subnet["${each.value.az}_${each.value.type}"].id
}

resource "aws_eip" "nat_gateway" {
  vpc = true

  tags = {
    Name = "${var.environment.name}-nat-gateway-${var.environment.region}a"
  }
}

resource "aws_nat_gateway" "a_public" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.subnet["a_public"].id

  tags = {
    Name = "${var.environment.name}-nat-gateway-${var.environment.region}a"
  }
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

  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = aws_route_table.private["${each.value.az}_${each.value.type}"].id
  nat_gateway_id         = aws_nat_gateway.a_public.id
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

