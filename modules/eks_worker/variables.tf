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

variable "instance_type" {
	description = "Instance type of the worker node like t2-medium"
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

variable "bastion_sg" {
	description = "bastion security group id"
}

variable "cluster_security_group_id" {
	description = "cluster security group"
}

variable "desired_capacity" {
	description = "Desired capacity of the worker node asg"
}