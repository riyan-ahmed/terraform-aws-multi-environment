terraform {
  required_version = "~> 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72.0"
    }
  }

  backend "s3" {
    bucket       = "riyan-terraform-state-2026"
    key          = "stag/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}