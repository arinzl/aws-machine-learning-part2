
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block_module
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.app_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  availability_zone = local.filtered_azs[0]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-${local.filtered_azs[0]}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-public"
  }
}

# Default Route to Internet Gateway
resource "aws_route" "public_default_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "${var.app_name}-nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.app_name}-nat-gateway"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                   = length(local.filtered_azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 16 + count.index)
  availability_zone       = local.filtered_azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.app_name}-private-${local.filtered_azs[count.index]}"
  }
}

# Route Tables for Private Subnets
resource "aws_route_table" "private" {
  count = length(local.filtered_azs)

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-private-${local.filtered_azs[count.index]}"
  }
}

# Default Route to NAT Gateway for Private Subnets
resource "aws_route" "private_default_route" {
  count = length(local.filtered_azs)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# Associate Private Subnets with Their Route Tables
resource "aws_route_table_association" "private" {
  count = length(local.filtered_azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Default Security Group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-vpc-default"
  }
}
