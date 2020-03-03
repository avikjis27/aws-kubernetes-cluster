variable "cluster_name" {
	description = "Cluster name"
}

variable "eks_cluster_version" {
	description = "Cluster version"
}

variable "eks_cluster_ep" {
	description = "Cluster endpoint"
}

variable "eks_certificate_authority_data" {
	description = "Cluster certificate authority"
}

variable "vpc_id" {
	description = "EKS vpc id"
}

variable "tags" {
	 description = "Common tags of all the resources"
	 type        = "map"
}

variable "master_security_group_id" {
	description = "Security group id of the master"
}

variable "private_subnet_ids" {
	description = "Private subnet id"
	type = list(string)
}