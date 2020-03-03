variable "cluster_name" {
	description = "EKS cluster name"
}

variable "vpc_id" {
	description = "EKS vpc id"
}

variable "external_ips" {
	description = "List of external ips with CIDR from which to access the cluster "
	type = list(string)
}

variable "eks_cluster_subnet_ids" {
  description = "List of subnet IDs. Must be in at least two different availability zones. Amazon EKS creates cross-account elastic network interfaces in these subnets to allow communication between your worker nodes and the Kubernetes control plane"
  type = list(string)
}

variable "tags" {
	 description = "Common tags of all the resources"
	 type        = "map"
}

