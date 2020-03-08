variable "tags" {
  description = "Common tags of all the resources"
  type        = "map"
}
variable "region" {
  description = "aws region"
}
variable "profile" {
  description = "aws profile"
}
variable "cidr_block" {
  description = "VPC CIDR Block"
}
variable "external_subnets" {
  description = "vpc internet facing subnet"
  type        = list(string)
}
variable "internal_subnets" {
  description = "vpc internal subnet"
  type        = list(string)
}
variable "availability_zones" {
  description = "vpc availability zone to be used"
  type        = list(string)
}
variable "external_ips" {
  description = "external ip with CIDR that can connect eks cluster from outside"
  type        = list(string)
}
variable "cluster_name" {
  description = "EKS cluster name"
}
