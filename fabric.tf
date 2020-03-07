/*
The fabric layer contains
1. The VPC
2. Two subnets(internal or private and external or public) inside the VPC
3. Two Route tables for internal and external subnets
4. Two corresponding route table associations
5. Required Routes
6. Security groups
7. Internet gateway in external subnet
8. NAT-GW in the external subnet
9. Required EIP for NAT-GW
10. S3 Buckets
11. DNS names





*/




// VPC

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge( var.tags, 
	  { 
		  Name = var.cluster_name,
		  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
	  }
	)
}

// Internet Gateways

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags   = merge( var.tags, 
	  { 
		  Name = "eks_internet_gw"
	  }
	)
}

resource "aws_eip" "nat_eip" {
  vpc                       = true
  associate_with_private_ip = "10.30.1.6"
  tags                 = merge( var.tags, 
	  { 
		  Name = "nat_eip"
	  }
	)
}

//NAT Gateway

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.external.*.id, 0)
  depends_on = ["aws_internet_gateway.internet_gateway"]
  tags                 = merge( var.tags, 
	  { 
		  Name = "nat_gw"
	  }
	)
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
		  Name = "subnet-internal-${format("%03d", count.index + 1)}",
		  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
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
		Name = "subnet-external-${format("%03d", count.index + 1)}" ,
		"kubernetes.io/cluster/${var.cluster_name}" = "shared"
	},
  )
}

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
  count  = length(var.availability_zones)
  route_table_id         = element(aws_route_table.external.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "internal" {
  count  = length(var.availability_zones)
  route_table_id         = element(aws_route_table.internal.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.nat_gateway.id
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
  policy = <<POLICY
{
    "Id": "Policy1583146367012",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1583146359660",
            "Action": [
                "s3:GetBucketLocation"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:s3:::eks.sandbox.devops.onelxk.co",
            "Principal": "*"
        }
    ]
}
POLICY
  

  tags = merge(
	  var.tags,
      { 
		  Name = "kops_bucket" 
	  },
  )
}


module "eks_master" {
  source      	= "./modules/eks_master"
  cluster_name	= var.cluster_name
  vpc_id		= aws_vpc.main.id
  external_ips	= var.external_ips
  eks_cluster_subnet_ids = aws_subnet.internal.*.id
  tags			= var.tags

}

module "eks_worker" {
	source      	= "./modules/eks_worker"
	cluster_name	= var.cluster_name
	eks_cluster_version = module.eks_master.eks_cluster_version
	eks_cluster_ep 	= module.eks_master.eks_cluster_ep
	eks_certificate_authority_data = module.eks_master.eks_certificate_authority_data
	vpc_id			= aws_vpc.main.id
	master_security_group_id = module.eks_master.master_security_group_id
	private_subnet_ids = aws_subnet.external.*.id
	tags			= var.tags
}

locals {
  config_map_aws_auth = <<CONFIGMAPAWSAUTH


apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${module.eks_worker.eks_worker_role_arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

}




// Outputs
output "vpc_id"             { value = aws_vpc.main.id }
output "cidr_block"         { value = aws_vpc.main.cidr_block }
output "external_subets"    { value = aws_subnet.external.* }
output "availability_zones" { value = var.availability_zones }
output "hosted_zone_id" 	{ value = aws_route53_zone.eks_domain.zone_id}
output "kops_bucket_name"	{ value = aws_s3_bucket.kops_bucket.id }
output "config_map_aws_auth" { value = local.config_map_aws_auth }