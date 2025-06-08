terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60.0"
    }
  }

  backend "s3" {
    bucket  = "isu-aws-tfstate-528452590477"
    key     = "s3-terraform.tfstate"
    region  = "ap-northeast-1"
    #profile = "terraform"
  }
}
