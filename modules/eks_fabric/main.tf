/*
https://learn.hashicorp.com/terraform/aws/eks-intro
*/

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(var.tags,
    {
      Name                                        = var.cluster_name,
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

output "vpc_id" { value = aws_vpc.main.id }

// Internet Gateways


resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags,
    {
      Name = "eks_internet_gw"
    }
  )
}

output "internet_gateway" { value = aws_internet_gateway.internet_gateway.id } 

resource "aws_eip" "nat_eip" {
  vpc                       = true
  associate_with_private_ip = "10.30.1.6"
  tags = merge(var.tags,
    {
      Name = "nat_eip"
    }
  )
}

//NAT Gateway

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.external.*.id, 0)
  depends_on    = ["aws_internet_gateway.internet_gateway"]
  tags = merge(var.tags,
    {
      Name = "nat_gw"
    }
  )
}

output "nat_gateway" { value = aws_eip.nat_eip.id }
// Subnets

resource "aws_subnet" "internal" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.internal_subnets, count.index)
  availability_zone = element(sort(var.availability_zones), count.index)
  count             = length(var.internal_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  tags = merge(
    var.tags,
    {
      Name                                        = "subnet-internal-${format("%03d", count.index + 1)}",
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

output "internal_subnet" { value = aws_subnet.internal.*.id }

resource "aws_subnet" "external" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.external_subnets, count.index)
  availability_zone       = element(sort(var.availability_zones), count.index)
  count                   = length(var.external_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  map_public_ip_on_launch = true

  tags = merge(var.tags,
    {
      Name                                        = "subnet-external-${format("%03d", count.index + 1)}",
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    },
  )
}

output "external_subnet" { value = aws_subnet.external.*.id }

// Route Tables

resource "aws_route_table" "external" {
  vpc_id = aws_vpc.main.id
  count  = length(var.availability_zones)
  tags = merge(var.tags,
    {
      Name = "route-table-external-${format("%03d", count.index + 1)}"
    },
  )
}

resource "aws_route_table" "internal" {
  vpc_id = aws_vpc.main.id
  count  = length(var.availability_zones)

  tags = merge(
    var.tags,
    {
      Name = "route-table-internal-${format("%03d", count.index + 1)}"
    },
  )
}

resource "aws_route" "external" {
  count                  = length(var.availability_zones)
  route_table_id         = element(aws_route_table.external.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "internal" {
  count                  = length(var.availability_zones)
  route_table_id         = element(aws_route_table.internal.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}

// Route associations

resource "aws_route_table_association" "internal" {
  count          = length(var.internal_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  subnet_id      = element(aws_subnet.internal.*.id, count.index)
  route_table_id = element(aws_route_table.internal.*.id, count.index)
}

resource "aws_route_table_association" "external" {
  count          = length(var.external_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  subnet_id      = element(aws_subnet.external.*.id, count.index)
  route_table_id = element(aws_route_table.external.*.id, count.index)
}


// Security Group

resource "aws_security_group" "main" {
  vpc_id      = aws_vpc.main.id
  name_prefix = "main-"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



