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
  ssh_key = length(digitalocean_ssh_key.dev_ssh_key) == 1 ? {
    public_key  = digitalocean_ssh_key.dev_ssh_key[0].public_key,
    fingerprint = digitalocean_ssh_key.dev_ssh_key[0].fingerprint
  } : null
  vms = [
    module.business_logic_vm,
    module.logging_vm,
    module.db_access_vm
  ]
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
# TRANSFER SSH KEY TO DIGITALOCEAN IF IN DEVELOPMENT ENVIRONMENT AND
# SSH KEY IS PROVIDED.
# To be used for SSH access to all VMs.
# ------------------------------------------------------------------------------
resource "digitalocean_ssh_key" "dev_ssh_key" {
  count = local.environment == "development" && var.ssh_public_key_path != null ? 1 : 0

  name       = "Dev SSH key (${local.environment})"
  public_key = file(var.ssh_public_key_path)
}

# ------------------------------------------------------------------------------
# DEPLOY VM FOR BUSINESS LOGIC APPLICATION
# ------------------------------------------------------------------------------
module "business_logic_vm" {
  source = "./do-application-vm"

  vm_name          = "business-logic"
  do_region        = var.do_region
  do_vm_size       = local.vm_size_per_environment[local.environment]
  ssh_key          = local.ssh_key
  aws_config       = local.aws_config
  app_start_script = data.template_file.business_logic_app_bootstrap_config.rendered
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
    logging_app_host_url           = "${module.logging_vm.ipv4_address}:8080"
    db_access_app_1_host_url       = "${module.db_access_vm.ipv4_address}:8080"
    db_access_admin_app_1_host_url = "${module.db_access_vm.ipv4_address}:8081"
    db_access_app_2_host_url       = "${module.db_access_vm.ipv4_address}:9080"
    db_access_admin_app_2_host_url = "${module.db_access_vm.ipv4_address}:9081"
  }
}

# ------------------------------------------------------------------------------
# DEPLOY VM FOR LOGGING APPLICATION
# ------------------------------------------------------------------------------
module "logging_vm" {
  source = "./do-application-vm"

  vm_name          = "logging"
  do_region        = var.do_region
  do_vm_size       = local.vm_size_per_environment[local.environment]
  ssh_key          = local.ssh_key
  aws_config       = local.aws_config
  app_start_script = data.template_file.logging_app_bootstrap_config.rendered
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT TO START THE LOGGING APPLICATION ON VM.
# To be run when the VM boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "logging_app_bootstrap_config" {
  template = file("${path.module}/app-start-scripts/logging-app-bootstrap.tpl")

  vars = {
    ecr_base_url                 = local.ecr_base_url
    app_docker_compose_bucket_id = local.app_docker_compose_bucket_id
    logging_app_repo_url         = local.ecr_repos["logging-app"].repository_url
    block_storage_name           = local.environment == "production" ? data.terraform_remote_state.global.outputs.prod_log_data_block_storage.name : ""
    block_storage_mount_name     = local.environment == "production" ? replace(data.terraform_remote_state.global.outputs.prod_log_data_block_storage.name, "-", "_") : "" # All dash becomes underscore
  }
}

# ------------------------------------------------------------------------------
# ATTACH PERSISTENT BLOCK STORAGE TO LOGGING APP VM
# ------------------------------------------------------------------------------
resource "digitalocean_volume_attachment" "logging_data_block_attachment" {
  count = local.environment == "production" ? 1 : 0

  droplet_id = module.logging_vm.id
  volume_id  = data.terraform_remote_state.global.outputs.prod_log_data_block_storage.id
}

# ------------------------------------------------------------------------------
# DEPLOY VM FOR DB ACCESS APPLICATION
# ------------------------------------------------------------------------------
module "db_access_vm" {
  source = "./do-application-vm"

  vm_name          = "db-access"
  tags             = [data.terraform_remote_state.global.outputs.db_allowed_droplet_tags[local.environment].name]
  do_region        = var.do_region
  do_vm_size       = local.vm_size_per_environment[local.environment]
  ssh_key          = local.ssh_key
  aws_config       = local.aws_config
  app_start_script = data.template_file.db_access_app_bootstrap_config.rendered
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
    logging_app_host_url         = "${module.logging_vm.ipv4_address}:8080"
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
