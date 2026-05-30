terraform {
  backend "s3" {
    bucket         = "motg-terraform-state-us-east-1"   # from bootstrap output: state_bucket_name
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "motg-terraform-locks"              # from bootstrap output: dynamodb_table_name
    encrypt        = true
  }
}
