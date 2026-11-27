terraform {
  required_version = ">= 1.13" # Terraform or OpenTofu; Terragrunt users pin their own in .terraform-version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.20" # the lowest version this module has run on (both stages' lock files)
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2"
    }
  }
}
