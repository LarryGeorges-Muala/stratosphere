terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36.0"
    }
  }

  required_version = "~> 1.6"
}

provider "aws" {
  region  = local.main_region
  profile = "terraform"
}
