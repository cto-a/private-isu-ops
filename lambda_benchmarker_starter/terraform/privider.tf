provider "aws" {
  region  = "ap-northeast-1"
  profile = "ctoa2024"
}

terraform {
  backend "s3" {
    bucket = "isu-aws-tfstate"
    key    = "lambda.tfstate"
    region = "ap-northeast-1"
  }
}
