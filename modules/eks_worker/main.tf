//See https://docs.aws.amazon.com/eks/latest/userguide/worker_node_IAM_role.html
resource "aws_iam_role" "worker_role" {
  name = "terraform-eks-worker-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
	{
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_instance_profile" "k8s-node" {
  name = var.cluster_name
  role = aws_iam_role.worker_role.name
  depends_on = [
    "aws_iam_role_policy_attachment.eks-worker-AmazonEKSWorkerNodePolicy",
    "aws_iam_role_policy_attachment.eks-worker-AmazonEKSCNIPolicy",
	 "aws_iam_role_policy_attachment.eks-worker-AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEKSCNIPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_role.name
}

resource "aws_iam_role_policy_attachment" "eks-worker-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_role.name
}

# resource "aws_security_group" "eks-worker-sg" {
#   name        = "terraform-eks-worker-sg"
#   description = "Security group for all nodes in the cluster"
#   vpc_id      = var.vpc_id

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name                                        = "terraform-eks-worker-sg",
#       "kubernetes.io/cluster/${var.cluster_name}" = "owned"
#     },
#   )
# }

# resource "aws_security_group_rule" "ingress-self" {
#   description              = "Allow node to communicate with each other"
#   from_port                = 0
#   protocol                 = "-1"
#   security_group_id        = aws_security_group.eks-worker-sg.id
#   source_security_group_id = aws_security_group.eks-worker-sg.id
#   to_port                  = 65535
#   type                     = "ingress"
# }

resource "aws_security_group_rule" "ingress-bastion" {
  description              = "Allow node to communicate with each other"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = var.cluster_security_group_id
  source_security_group_id = var.bastion_sg
  to_port                  = 443
  type                     = "ingress"
}

# resource "aws_security_group_rule" "ingress-cluster" {
#   description              = "Allow worker Kubelets and pods to receive communication from the cluster control      plane"
#   from_port                = 1025
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks-worker-sg.id
#   source_security_group_id = var.master_security_group_id
#   to_port                  = 65535
#   type                     = "ingress"
# }

# #Worker Node Access to EKS Master Cluster
# resource "aws_security_group_rule" "ingress-node-https" {
#   description              = "Allow pods to communicate with the cluster API Server"
#   from_port                = 443
#   protocol                 = "tcp"
#   security_group_id        = var.master_security_group_id
#   source_security_group_id = aws_security_group.eks-worker-sg.id
#   to_port                  = 443
#   type                     = "ingress"
# }

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.eks_cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["amazon"]
}

# EKS currently documents this required userdata for EKS worker nodes to
# properly configure Kubernetes applications on the EC2 instance.
# We implement a Terraform local here to simplify Base64 encoding this
# information into the AutoScaling Launch Configuration.
# More information: https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html
locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${var.eks_cluster_ep}' --b64-cluster-ca '${var.eks_certificate_authority_data}' '${var.cluster_name}'
USERDATA

}

resource "aws_launch_configuration" "eks_launch_configuration" {
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k8s-node.name
  image_id                    = data.aws_ami.eks-worker.id
  instance_type               = var.instance_type
  name_prefix                 = "terraform-eks"
  security_groups             = [var.cluster_security_group_id]
  user_data_base64            = base64encode(local.eks-node-userdata)
  key_name                    = "ISS-DevOps-west-2"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "eks_asg" {
  desired_capacity     = var.desired_capacity
  launch_configuration = aws_launch_configuration.eks_launch_configuration.id
  max_size             = 4
  min_size             = 0
  name                 = "terraform-eks-asg"
  vpc_zone_identifier  = var.private_subnet_ids

  tag {
    key                 = "Name"
    value               = "eks-worker-nodes"
	propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = ""
    propagate_at_launch = true
  }

}

output "eks_worker_role_arn" { value = aws_iam_role.worker_role.arn }
