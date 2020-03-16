

This is a demo project to create a working EKS cluster using terraform only.
[Medium post](https://medium.com/@avikjis27/build-an-eks-cluster-using-terraform-ecf011e37884)

### For this project I have used
	- Terraform v0.12.13
	- provider.aws v2.46.0
	- AWS account

### How to run

- `make plan` to get the plan
- `make apply` to provision the infra
- `make destroy` to destroy the infra


### Important links

- [EKS with terraform](https://learn.hashicorp.com/terraform/aws/eks-intro)

- [5 things you need to know to add worker nodes in the AWS EKS cluster](https://medium.com/@tarunprakash/5-things-you-need-know-to-add-worker-nodes-in-the-aws-eks-cluster-bfbcb9fa0c37)
