terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.28.0"
    }
  }


  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "ACG-Terraform-Labs-Teste"

    workspaces {
      name = "lab-migrate-state"
    }
  }
}

provider "aws" {
  access_key = "AKIATKICYNR45KMHZV6F"
  secret_key = "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"
  region     = "us-east-2"
}

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "us-east-2"
}