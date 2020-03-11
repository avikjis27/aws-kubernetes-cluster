resource "aws_instance" "bastion" {
  ami                         = "ami-0f5eb23d395788b75"
  instance_type               = "t2.nano"
  associate_public_ip_address = true
  key_name                    = "ISS-DevOps-west-2"
  subnet_id					  = element(aws_subnet.external.*.id, 0)
  security_groups 			  = [aws_security_group.bastion.id, aws_security_group.main.id]
  tags = merge(
    var.tags,
    {
      Name = "eks-bastion"
    },
  )
}
output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}

resource "aws_security_group" "bastion" {
  name   = "bastion-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "eks-bastion-sg"
    },
  )
}
output "bastion_sg" {
  value = "${aws_security_group.bastion.id}"
}
