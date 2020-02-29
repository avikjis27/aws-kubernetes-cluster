// VPC

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge( var.tags, 
	  { 
		  Name = "eks-test-vpc" 
	  }
	)
}

// Gateways

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = var.tags
}

// Subnets

resource "aws_subnet" "internal" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.internal_subnets, count.index)
  availability_zone = element(sort(var.availability_zones), count.index)
  count             = length(var.internal_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  tags              = merge(
	  var.tags, 
	  { 
		  Name = "subnet-internal-${format("%03d", count.index + 1)}" 
	  }
	)
}

resource "aws_subnet" "external" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.external_subnets, count.index)
  availability_zone       = element(sort(var.availability_zones), count.index)
  count                   = length(var.external_subnets) >= length(var.availability_zones) ? length(var.availability_zones) : 0
  map_public_ip_on_launch = true

  tags = merge(var.tags,
    {
		Name = "subnet-external-${format("%03d", count.index + 1)}" 
	},
  )
}

// Route Tables

resource "aws_route_table" "external" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.tags,
    { 
		Name = "route-table-external-001" 
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
  route_table_id         = aws_route_table.external.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id //This is the source
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
  route_table_id = aws_route_table.external.id
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


data "aws_route53_zone" "sandbox_public_hosted_zone" {
  name   = "sandbox.devops.onelxk.co"
}
// Hosted zones as subdomain of sandbox.devops.onelxk.co
resource "aws_route53_zone" "eks_domain" {
  name = "eks.sandbox.devops.onelxk.co"

  tags = merge(
	  var.tags,
      { 
		  Name = "eks_domain" 
	  },
  )
}

resource "aws_route53_record" "sandbox_eks_domain" {
  zone_id = data.aws_route53_zone.sandbox_public_hosted_zone.zone_id
  name    = "eks.sandbox.devops.onelxk.co"
  type    = "NS"
  ttl     = "30"

  records = [
    aws_route53_zone.eks_domain.name_servers.0,
    aws_route53_zone.eks_domain.name_servers.1,
    aws_route53_zone.eks_domain.name_servers.2,
    aws_route53_zone.eks_domain.name_servers.3,
  ]
}

// S3 bucket to store kops state
resource "aws_s3_bucket" "kops_bucket" {
  bucket = "eks.sandbox.devops.onelxk.co"
  acl    = "private"

  tags = merge(
	  var.tags,
      { 
		  Name = "kops_bucket" 
	  },
  )
}


// Outputs
output "vpc_id"             { value = aws_vpc.main.id }
output "cidr_block"         { value = aws_vpc.main.cidr_block }
output "external_subets"    { value = aws_subnet.external.* }
output "availability_zones" { value = var.availability_zones }
output "hosted_zone_id" 	{ value = aws_route53_zone.eks_domain.zone_id}
output "kops_bucket_name"	{ value = aws_s3_bucket.kops_bucket.id }