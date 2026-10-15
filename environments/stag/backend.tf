terraform {
  backend "s3" {
    bucket       = "riyan-terraform-state-2026"
    key          = "stag/terraform.tfstate"
    region       = "eu-west-2"
    use_lockfile = true
  }
}