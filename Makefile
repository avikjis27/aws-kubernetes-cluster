init:
	terraform init 
plan: init
	terraform plan -var-file ./configs/sandbox.tfvars
apply: init
	terraform apply -var-file ./configs/sandbox.tfvars
	terraform output config_map_aws_auth > config_map_aws_auth.yaml
	aws --region us-west-2 --profile sandbox-us-west-2 eks update-kubeconfig  --name eks-sandbox  --alias sandbox-eks
	kubectl apply -f config_map_aws_auth.yaml
destroy: init
	terraform destroy -var-file ./configs/sandbox.tfvars