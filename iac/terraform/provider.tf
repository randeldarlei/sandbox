terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.28.0"
    }
  }
}

provider "aws" {
  access_key  = "AKIATKICYNR4VP3GJ6KI"
  secret_key = "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"
  region = "us-east-2"
}
