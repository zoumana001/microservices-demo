terraform {
  backend "s3" {
    bucket         = "zoum-terraform-state"
    key            = "zoum-cluster/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "zoum-terraform-locks"
  }
}
