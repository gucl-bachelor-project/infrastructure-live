# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SETUP MAIN RESOURCES FOR LIVE APPLICATION IN DIGITALOCEAN
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "digitalocean" {
  token = var.do_api_token
}

# ------------------------------------------------------------------------------
# DEFINE ENVIRONMENT BASED ON TERRAFORM WORKSPACE.
# See: https://www.terraform.io/docs/state/workspaces.html
# ------------------------------------------------------------------------------
locals {
  environment = contains(["production", "staging"], terraform.workspace) ? terraform.workspace : "development"
}

# ------------------------------------------------------------------------------
# USE REMOTE BACKEND FOR INFRASTRUCTURE IN LIVE APPLICATION
# ------------------------------------------------------------------------------
terraform {
  backend "s3" {
    encrypt        = true
    key            = "live/terraform.tfstate"
    region         = "eu-central-1"
    bucket         = "gkc-bproject-terraform-backend"
    dynamodb_table = "gkc-bproject-terraform-lock"
  }
}

# ------------------------------------------------------------------------------
# ACCESS DATA FROM 'GLOBAL' INFRASTRUCTURE MODULE
# ------------------------------------------------------------------------------
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "gkc-bproject-terraform-backend"
    key    = "global/terraform.tfstate"
    region = "eu-central-1"
  }
}

# ------------------------------------------------------------------------------
# SETUP PROJECT IN DIGITALOCEAN TO GROUP RESOURCES (VMs AND DOMAIN RECORDS)
# IN CURRENT ENVIRONMENT.
# ------------------------------------------------------------------------------
resource "digitalocean_project" "project" {
  name        = "Bproject – ${terraform.workspace}"
  environment = local.environment
  resources   = concat([for vm in local.vms : vm.urn], [for domain in digitalocean_domain.domain : domain.urn])
}
