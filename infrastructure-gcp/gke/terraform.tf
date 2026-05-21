terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.33.0"
    }
  }

  required_version = "~> 1.6"
}

provider "google" {
  project     = "stratosphere"
  region      = local.region
}
