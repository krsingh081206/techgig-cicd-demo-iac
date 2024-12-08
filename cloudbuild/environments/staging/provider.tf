terraform {
  required_version = ">=1.0.9"
  backend "gcs" {
    bucket = "gcpdemo-terraform-tfstate"
    prefix = "terraform/state/stage"
  }
  required_providers {
    google = {
        source = "hashicorp/google"
        version = "5.31.1"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "5.29.1"
    }
  }
}
