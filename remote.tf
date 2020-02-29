terraform {
  backend "s3" {
    bucket  = "eks-test-state-bucket"
    key     = "eks.tfstate"
    region  = "us-west-2"
    profile = "sandbox-us-west-2"
  }
}
