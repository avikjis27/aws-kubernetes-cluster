#!/bin/bash -ex

export AWS_PROFILE="sandbox-us-west-2"

kops create cluster --zones='us-west-2a,us-west-2b' \
    --vpc=`terraform output vpc_id` \
    --network-cidr=`terraform output cidr_block` \
    --networking='kubenet' \
    --ssh-public-key='~/.ssh/id_rsa.pub' \
    --target="terraform" \
    --name=`terraform output kops_bucket_name` \
	--state=s3://`terraform output kops_bucket_name` \
    --out=kubernetes