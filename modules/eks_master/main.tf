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
    security_group_ids = [aws_security_group.eks-master-sg.id]
    subnet_ids         = var.eks_cluster_subnet_ids
  }
  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
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

# OPTIONAL: Allow inbound traffic from your local workstation external IP
#           to the Kubernetes. You will need to replace A.B.C.D below with
#           your real IP. Services like icanhazip.com can help you find this.
resource "aws_security_group_rule" "eks-cluster-ingress-workstation-https" {
  cidr_blocks       = var.external_ips
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.eks-master-sg.id}"
  to_port           = 443
  type              = "ingress"
}


output "master_security_group_id" { value = aws_security_group.eks-master-sg.id }
output "eks_cluster_version" { value = aws_eks_cluster.eks_cluster.version }
output "eks_certificate_authority_data" { value = aws_eks_cluster.eks_cluster.certificate_authority.0.data }
output "eks_cluster_ep" { value = aws_eks_cluster.eks_cluster.endpoint }
output "eks_cluster_role_arn" { value = aws_iam_role.master_role.arn }
