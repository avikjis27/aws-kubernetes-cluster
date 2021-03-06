# See https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html
resource "aws_iam_role" "master_role" {
  name = "terraform-eks-master-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master_role.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master_role.name
}


resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.master_role.arn

  vpc_config {
    subnet_ids         = var.eks_cluster_subnet_ids
  }
  // See https://aws.amazon.com/premiumsupport/knowledge-center/eks-cluster-autoscaler-setup/ to undestand the tags
  tags = merge(
    var.tags,
    {
      Name = var.cluster_name,
	  "k8s.io/cluster-autoscaler/enabled" = "",
    },
  )

  depends_on = [
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.eks-cluster-AmazonEKSServicePolicy",
  ]
}


resource "aws_security_group" "eks-master-sg" {
  name        = "terraform-eks-master-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name                                        = "terraform-eks-master-sg",
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
  )
}


resource "aws_security_group_rule" "eks-cluster-ingress-workstation-https" {
  cidr_blocks       = var.external_ips
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  to_port           = 443
  type              = "ingress"
}


output "cluster_security_group_id" { value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id }
output "eks_cluster_version" { value = aws_eks_cluster.eks_cluster.version }
output "eks_certificate_authority_data" { value = aws_eks_cluster.eks_cluster.certificate_authority.0.data }
output "eks_cluster_ep" { value = aws_eks_cluster.eks_cluster.endpoint }
output "eks_cluster_role_arn" { value = aws_iam_role.master_role.arn }
