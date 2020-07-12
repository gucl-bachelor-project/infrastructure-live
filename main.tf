# ------------------------------------------------------------------------------
# SET UP DIGITALOCEAN PROVIDER
# ------------------------------------------------------------------------------
provider "digitalocean" {
  token = var.do_api_token
}

# ------------------------------------------------------------------------------
# DETERMINE ENVIRONMENT BASED ON TERRAFORM WORKSPACE
# See: https://www.terraform.io/docs/state/workspaces.html
# ------------------------------------------------------------------------------
locals {
  environment          = contains(["production", "staging"], terraform.workspace) ? terraform.workspace : "development"
  global_module_output = data.terraform_remote_state.global.outputs # Output values from 'global' module
}

# ------------------------------------------------------------------------------
# REFERENCE REMOTE BACKEND WHERE THE TERRAFORM STATE IS STORED AND LOADED
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
# REFERENCE REMOTE BACKEND WHERE STATE OF 'GLOBAL' MODULE IS STORED TO
# ACCESS ITS OUTPUTS
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
# SETUP PROJECT IN DIGITALOCEAN TO GROUP RESOURCES IN CURRENT ENVIRONMENT
# ------------------------------------------------------------------------------
resource "digitalocean_project" "project" {
  name        = "Bproject – ${terraform.workspace}"
  environment = local.environment
  resources   = [for vm in local.vms : vm.urn]
}
