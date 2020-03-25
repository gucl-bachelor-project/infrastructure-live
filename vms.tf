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
}

# ------------------------------------------------------------------------------
# CREATE SSH KEY ON DIGITALOCEAN IF IN DEVELOPMENT ENVIRONMENT AND
# SSH KEY IS PROVIDED.
# To be used for SSH access to all VMs.
# ------------------------------------------------------------------------------
resource "digitalocean_ssh_key" "dev_ssh_key" {
  count = local.environment == "development" && var.ssh_public_key_path != null ? 1 : 0

  name       = "Dev SSH key (${local.environment})"
  public_key = file(var.ssh_public_key_path)
}

# ------------------------------------------------------------------------------
# CREATE VM FOR BUSINESS LOGIC APPLICATION
# ------------------------------------------------------------------------------
module "business_logic_vm" {
  source = "./do-application-vm"

  vm_name                     = "business-logic"
  do_region                   = var.do_region
  do_vm_size                  = local.vm_size_per_environment[local.environment]
  ssh_key                     = local.ssh_key
  aws_config                  = local.aws_config
  app_bootstrap_config_script = data.template_file.business_logic_app_bootstrap_config.rendered
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR BUSINESS LOGIC VM.
# To be run when the VM with the business logic application boots for the
# first time.
# ------------------------------------------------------------------------------
data "template_file" "business_logic_app_bootstrap_config" {
  template = file("${path.module}/do-application-vm/init-config-templates/services/business-logic-app-bootstrap.tpl")

  vars = {
    ecr_base_url                   = data.terraform_remote_state.global.outputs.ecr_base_url
    app_docker_compose_bucket_id   = data.terraform_remote_state.global.outputs.app_docker_composes_bucket_id
    main_app_repo_url              = data.terraform_remote_state.global.outputs.image_registries["bl-main-app"].repository_url
    support_app_repo_url           = data.terraform_remote_state.global.outputs.image_registries["bl-support-app"].repository_url
    logging_app_host_url           = "${module.logging_vm.ipv4_address}:8080"
    db_access_app_1_host_url       = "${module.db_access_vm.ipv4_address}:8080"
    db_access_admin_app_1_host_url = "${module.db_access_vm.ipv4_address}:8081"
    db_access_app_2_host_url       = "${module.db_access_vm.ipv4_address}:9080"
    db_access_admin_app_2_host_url = "${module.db_access_vm.ipv4_address}:9081"
  }
}

# ------------------------------------------------------------------------------
# CREATE VM FOR LOGGING APPLICATION
# ------------------------------------------------------------------------------
module "logging_vm" {
  source = "./do-application-vm"

  vm_name                     = "logging"
  do_region                   = var.do_region
  do_vm_size                  = local.vm_size_per_environment[local.environment]
  ssh_key                     = local.ssh_key
  aws_config                  = local.aws_config
  app_bootstrap_config_script = data.template_file.logging_app_bootstrap_config.rendered
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR LOGGING APP VM.
# To be run when the VM with the logging application boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "logging_app_bootstrap_config" {
  template = file("${path.module}/do-application-vm/init-config-templates/services/logging-app-bootstrap.tpl")

  vars = {
    ecr_base_url                 = data.terraform_remote_state.global.outputs.ecr_base_url
    app_docker_compose_bucket_id = data.terraform_remote_state.global.outputs.app_docker_composes_bucket_id
    logging_app_repo_url         = data.terraform_remote_state.global.outputs.image_registries["logging-app"].repository_url
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
# CREATE VM FOR DB ACCESS APPLICATION
# ------------------------------------------------------------------------------
module "db_access_vm" {
  source = "./do-application-vm"

  vm_name                     = "db-access"
  tags                        = ["db-access-app-${local.environment}"]
  do_region                   = var.do_region
  do_vm_size                  = local.vm_size_per_environment[local.environment]
  ssh_key                     = local.ssh_key
  aws_config                  = local.aws_config
  app_bootstrap_config_script = data.template_file.db_access_app_bootstrap_config.rendered
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR DB ACCESS APP VM.
# To be run when the VM with the DB access application boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "db_access_app_bootstrap_config" {
  template = file("${path.module}/do-application-vm/init-config-templates/services/db-access-app-bootstrap.tpl")

  vars = {
    ecr_base_url                 = data.terraform_remote_state.global.outputs.ecr_base_url
    app_docker_compose_bucket_id = data.terraform_remote_state.global.outputs.app_docker_composes_bucket_id
    logging_app_host_url         = "${module.logging_vm.ipv4_address}:8080"
    db_access_repo_url           = data.terraform_remote_state.global.outputs.image_registries["db-access-app"].repository_url
    db_access_admin_repo_url     = data.terraform_remote_state.global.outputs.image_registries["db-access-admin-app"].repository_url
    app_db_username              = data.terraform_remote_state.global.outputs.db_clusters[local.environment].app_user.name
    app_db_password              = data.terraform_remote_state.global.outputs.db_clusters[local.environment].app_user.password
    app_db_1_name                = data.terraform_remote_state.global.outputs.db_clusters[local.environment].dbs["app-db-1"].name
    app_db_2_name                = data.terraform_remote_state.global.outputs.db_clusters[local.environment].dbs["app-db-2"].name
    db_hostname                  = data.terraform_remote_state.global.outputs.db_clusters[local.environment].db_cluster.host
    db_port                      = data.terraform_remote_state.global.outputs.db_clusters[local.environment].db_cluster.port
  }
}
