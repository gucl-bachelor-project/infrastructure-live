# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY VMs FOR LIVE APPLICATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

locals {
  vm_size_per_environment = {
    production  = "s-2vcpu-4gb" # Medium
    staging     = "s-1vcpu-2gb" # Small
    development = "s-1vcpu-1gb" # Micro
  }
  # AWS config to use in VMs to access AWS resources/services (e.g. S3 buckets and ECR) during operation
  aws_config = {
    region            = data.terraform_remote_state.global.outputs.ecr_region.name
    access_key_id     = var.aws_access_key_id
    secret_access_key = var.aws_secret_access_key
  }
  vms = [
    module.business_logic_vm,
    module.db_access_vm
  ]
  logging_app_ip_address = data.terraform_remote_state.global.outputs.app_ips["logging_app_ip"].ip_address
  # Base URL of Amazon ECR where the Docker images for the application are stored
  ecr_base_url = data.terraform_remote_state.global.outputs.ecr_base_url
  # All Amazon ECR repositories where the Docker images for the application are stored
  ecr_repos = data.terraform_remote_state.global.outputs.image_repositories
  # ID of S3 bucket where the Docker Compose files for the application are stored
  app_docker_compose_bucket_id = data.terraform_remote_state.global.outputs.app_docker_composes_bucket_id
  # Environment-specific DB cluster for application
  db_cluster = data.terraform_remote_state.global.outputs.db_clusters[local.environment]
}

# ------------------------------------------------------------------------------
# REFERENCE ALL SSH KEYS REGISTERED IN DIGITALOCEAN THAT SHOULD BE MARKED AS
# AN AUTHORIZED KEY ON ALL VMS TO ALLOW SSH ACCESS.
# ------------------------------------------------------------------------------
data "digitalocean_ssh_key" "authorized_ssh_keys" {
  for_each = toset(var.authorized_ssh_keys)

  name = each.value
}

# ------------------------------------------------------------------------------
# FETCH BAKED OS IMAGE TO BOOT VMs ON
# ------------------------------------------------------------------------------
data "digitalocean_droplet_snapshot" "base_snapshot" {
  name_regex  = "^gkc-bproject-packer"
  region      = "fra1"
  most_recent = true
}

# ------------------------------------------------------------------------------
# DEPLOY VM FOR BUSINESS LOGIC APPLICATION
# ------------------------------------------------------------------------------
module "business_logic_vm" {
  source = "github.com/gucl-bachelor-project/infrastructure-modules//do-application-vm?ref=v1.0.0"

  vm_name             = "business-logic"
  boot_image_id       = data.digitalocean_droplet_snapshot.base_snapshot.id
  do_region           = var.do_region
  do_vm_size          = local.vm_size_per_environment[local.environment]
  authorized_ssh_keys = data.digitalocean_ssh_key.authorized_ssh_keys
  aws_config          = local.aws_config
  app_start_script    = data.template_file.business_logic_app_bootstrap_config.rendered
  tags                = [data.terraform_remote_state.global.outputs.logging_app_allowed_droplet_tag_name]
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT TO START THE BUSINESS LOGIC APPLICATION ON VM.
# To be run when the VM boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "business_logic_app_bootstrap_config" {
  template = file("${path.module}/app-start-scripts/business-logic-app-bootstrap.tpl")

  vars = {
    ecr_base_url                   = local.ecr_base_url
    app_docker_compose_bucket_id   = local.app_docker_compose_bucket_id
    main_app_repo_url              = local.ecr_repos["bl-main-app"].repository_url
    support_app_repo_url           = local.ecr_repos["bl-support-app"].repository_url
    nginx_repo_url                 = local.ecr_repos["nginx"].repository_url
    logging_app_host_url           = "${local.logging_app_ip_address}:8080"
    db_access_app_1_host_url       = "${module.db_access_vm.ipv4_address}:8080"
    db_access_admin_app_1_host_url = "${module.db_access_vm.ipv4_address}:8081"
    db_access_app_2_host_url       = "${module.db_access_vm.ipv4_address}:9080"
    db_access_admin_app_2_host_url = "${module.db_access_vm.ipv4_address}:9081"
  }
}

# ------------------------------------------------------------------------------
# ASSIGN FLOATING IP BUSINESS LOGIC APP VM FOR "REAL" USER TRAFFIC IF PRODUCTION
# ------------------------------------------------------------------------------
resource "digitalocean_floating_ip_assignment" "logging_app_floating_ip_assignment" {
  count = local.environment == "production" ? 1 : 0

  ip_address = data.terraform_remote_state.global.outputs.app_ips.prod_app_ip.ip_address
  droplet_id = module.business_logic_vm.id
}

# ------------------------------------------------------------------------------
# DEPLOY VM FOR DB ACCESS APPLICATION
# ------------------------------------------------------------------------------
module "db_access_vm" {
  source = "github.com/gucl-bachelor-project/infrastructure-modules//do-application-vm?ref=v1.0.0"

  vm_name             = "db-access"
  boot_image_id       = data.digitalocean_droplet_snapshot.base_snapshot.id
  do_region           = var.do_region
  do_vm_size          = local.vm_size_per_environment[local.environment]
  authorized_ssh_keys = data.digitalocean_ssh_key.authorized_ssh_keys
  aws_config          = local.aws_config
  app_start_script    = data.template_file.db_access_app_bootstrap_config.rendered
  tags                = [
    data.terraform_remote_state.global.outputs.db_allowed_droplet_tags[local.environment].name,
    data.terraform_remote_state.global.outputs.logging_app_allowed_droplet_tag_name
  ]
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT TO START THE DB ACCESS APPLICATION ON VM.
# To be run when the VM boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "db_access_app_bootstrap_config" {
  template = file("${path.module}/app-start-scripts/db-access-app-bootstrap.tpl")

  vars = {
    ecr_base_url                 = local.ecr_base_url
    app_docker_compose_bucket_id = local.app_docker_compose_bucket_id
    logging_app_host_url         = "${local.logging_app_ip_address}:8080"
    db_access_repo_url           = local.ecr_repos["db-access-app"].repository_url
    db_access_admin_repo_url     = local.ecr_repos["db-access-admin-app"].repository_url
    app_db_username              = local.db_cluster.app_user.name
    app_db_password              = local.db_cluster.app_user.password
    app_db_1_name                = local.db_cluster.dbs["app-db-1"].name
    app_db_2_name                = local.db_cluster.dbs["app-db-2"].name
    db_hostname                  = local.db_cluster.db_cluster.host
    db_port                      = local.db_cluster.db_cluster.port
  }
}
