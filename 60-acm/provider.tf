terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.24.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-dev-state-remote"
    key          = "remote-state-acm"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}
