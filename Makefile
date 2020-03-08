init:
	terraform init 
plan: init
	terraform plan -var-file ./configs/sandbox.tfvars
apply: init
	terraform apply -var-file ./configs/sandbox.tfvars