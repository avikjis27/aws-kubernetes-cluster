tags = {
	"provisioned_by" = "devops",
	"env" = "test",
}
region = "us-west-2"
profile = "sandbox-us-west-2"
cidr_block = "10.30.0.0/16"
external_subnets = ["10.30.1.0/24","10.30.2.0/24"]
internal_subnets = ["10.30.3.0/24","10.30.4.0/24"]
availability_zones = ["us-west-2a", "us-west-2b"]
external_ips = ["61.16.136.118/32"]
cluster_name = "eks-sandbox"