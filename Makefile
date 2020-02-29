init:
	terraform init 
plan: init
	terraform plan -var-file config.tfvars
apply: init
	terraform apply -var-file config.tfvars