terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.28.0"
    }
  }
}

provider "aws" {
  access_key  = "AKIATKICYNR4RR3QHZMP"
  secret_key = "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"
  region = "us-east-2"
}
