# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# VMS AND THEIR CONFIGURATION (INCLUDING SECURITY AND BOOT CONFIG)
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

locals {
  # List of VMs in environment
  vms = [
    module.application_server,
    module.db_access_server
  ]
  vm_sizes = {
    micro  = "s-1vcpu-1gb"
    small  = "s-1vcpu-2gb"
    medium = "s-2vcpu-4gb"
  }
  vm_size_per_environment = {
    application_server = {
      production  = local.vm_sizes.medium
      staging     = local.vm_sizes.small
      development = local.vm_sizes.micro
    },
    db_access_server = {
      production  = local.vm_sizes.small
      staging     = local.vm_sizes.small
      development = local.vm_sizes.micro
    }
  }

  # DB cluster for environment
  db_cluster = local.global_module_output.db_clusters[local.environment]

  # IP address of logging server
  logging_app_host_ip_address = local.global_module_output.ips["logging_server"]

  # Base URL of Amazon ECR registry where the Docker images for the application are stored
  ecr_base_url = local.global_module_output.ecr_registry_base_url
  # All Amazon ECR repositories where the Docker images for the application are stored
  ecr_repos = local.global_module_output.ecr_repositories

  # Project bucket in DigitalOcean Spaces
  project_bucket_name   = local.global_module_output.project_bucket_name
  project_bucket_region = local.global_module_output.project_bucket_region
}

# ------------------------------------------------------------------------------
# REFERENCE ALL SSH KEYS REGISTERED IN DIGITALOCEAN THAT SHOULD BE REGISTERED
# AS AUTHORIZED KEYS ON ALL VMS TO ALLOW SSH ACCESS.
# ------------------------------------------------------------------------------
data "digitalocean_ssh_key" "authorized_ssh_keys" {
  for_each = toset(local.global_module_output.registered_ssh_keys_names)

  name = each.value
}

# ------------------------------------------------------------------------------
# REFERENCE BAKED OS IMAGE THAT VMS BOOTS FROM
# ------------------------------------------------------------------------------
data "digitalocean_droplet_snapshot" "base_snapshot" {
  name_regex  = "^bproject-app-vm-image"
  region      = var.do_region
  most_recent = true
}

# ------------------------------------------------------------------------------
# BASE FIREWALL FOR ALL VMS
# ------------------------------------------------------------------------------
resource "digitalocean_firewall" "base_vm_firewall" {
  name = "${terraform.workspace}-base-vm-firewall"

  droplet_ids = [module.application_server.id, module.db_access_server.id]

  # Inbound SSH traffic from all IPs allowed
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Outbound TCP/UDP/ICMP traffic to all IPs allowed
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ------------------------------------------------------------------------------
# DEPLOY APPLICATION SERVER
# ------------------------------------------------------------------------------
module "application_server" {
  source = "github.com/gucl-bachelor-project/infrastructure-modules//do-application-vm?ref=v2.0.0"

  vm_name                   = "application-server"
  boot_image_id             = data.digitalocean_droplet_snapshot.base_snapshot.id
  do_region                 = var.do_region
  do_vm_size                = lookup(local.vm_size_per_environment.application_server, local.environment, local.vm_sizes.micro)
  authorized_ssh_keys       = [for ssh_key in data.digitalocean_ssh_key.authorized_ssh_keys : ssh_key]
  pvt_key                   = var.pvt_key
  do_spaces_access_key      = var.do_spaces_access_key_id
  do_spaces_secret_key      = var.do_spaces_secret_access_key
  compose_files_bucket_path = "app-docker-compose-files/business-logic/"
  do_spaces_region          = local.project_bucket_region
  ecr_base_url              = local.ecr_base_url
  extra_cloud_init_config   = data.template_file.application_server_bootstrap_config.rendered
  project_bucket_name       = local.project_bucket_name
  tags                      = [local.global_module_output.logging_vm_allowed_droplet_tag_name]
}

# ------------------------------------------------------------------------------
# FIREWALL FOR APPLICATION SERVER
# ------------------------------------------------------------------------------
resource "digitalocean_firewall" "application_server_firewall" {
  name = "${terraform.workspace}-application-server-firewall"

  droplet_ids = [module.application_server.id]

  # All inbound TCP traffic allowed
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR APPLICATION SERVER.
# To be run when the VM boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "application_server_bootstrap_config" {
  template = file("${path.module}/vm-config-scripts/application-server-config.tpl")

  vars = {
    main_app_repo_url                      = local.ecr_repos["bl-main-app"].repository_url
    support_app_repo_url                   = local.ecr_repos["bl-support-app"].repository_url
    nginx_repo_url                         = local.ecr_repos["nginx"].repository_url
    logging_app_host_url                   = "${local.logging_app_host_ip_address}:8080"
    db_administration_app_1_host_url       = "${module.db_access_server.ipv4_address}:8080"
    db_admin_administration_app_1_host_url = "${module.db_access_server.ipv4_address}:8081"
    db_administration_app_2_host_url       = "${module.db_access_server.ipv4_address}:9080"
    db_admin_administration_app_2_host_url = "${module.db_access_server.ipv4_address}:9081"
  }
}

# ------------------------------------------------------------------------------
# ASSIGN FLOATING IP TO APPLICATION SERVER FOR USER TRAFFIC IF PRODUCTION
# ENVIRONMENT
# ------------------------------------------------------------------------------
resource "digitalocean_floating_ip_assignment" "application_server_floating_ip_assignment" {
  count = local.environment == "production" ? 1 : 0

  ip_address = local.global_module_output.ips["prod_website"]
  droplet_id = module.application_server.id
}

# ------------------------------------------------------------------------------
# DEPLOY DB ACCESS SERVER
# ------------------------------------------------------------------------------
module "db_access_server" {
  source = "github.com/gucl-bachelor-project/infrastructure-modules//do-application-vm?ref=v2.0.0"

  vm_name                   = "db-access-server"
  boot_image_id             = data.digitalocean_droplet_snapshot.base_snapshot.id
  do_region                 = var.do_region
  do_vm_size                = lookup(local.vm_size_per_environment.application_server, local.environment, local.vm_sizes.micro)
  authorized_ssh_keys       = [for ssh_key in data.digitalocean_ssh_key.authorized_ssh_keys : ssh_key]
  pvt_key                   = var.pvt_key
  do_spaces_access_key      = var.do_spaces_access_key_id
  do_spaces_secret_key      = var.do_spaces_secret_access_key
  compose_files_bucket_path = "app-docker-compose-files/persistence/"
  do_spaces_region          = local.project_bucket_region
  ecr_base_url              = local.ecr_base_url
  extra_cloud_init_config   = data.template_file.db_access_server_bootstrap_config.rendered
  project_bucket_name       = local.project_bucket_name
  tags = [
    local.global_module_output.db_allowed_droplet_tags[local.environment],
    local.global_module_output.logging_vm_allowed_droplet_tag_name
  ]
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR DB ACCESS SERVER.
# To be run when the VM boots for the first time.
# ------------------------------------------------------------------------------
data "template_file" "db_access_server_bootstrap_config" {
  template = file("${path.module}/vm-config-scripts/db-access-server-config.tpl")

  vars = {
    logging_app_host_url                 = "${local.logging_app_host_ip_address}:8080"
    db_administration_app_repo_url       = local.ecr_repos["db-administration-app"].repository_url
    db_admin_administration_app_repo_url = local.ecr_repos["db-admin-administration-app"].repository_url
    app_db_username                      = local.db_cluster.app_user.name
    app_db_password                      = local.db_cluster.app_user.password
    app_db_1_name                        = local.db_cluster.dbs["app-db-1"].name
    app_db_2_name                        = local.db_cluster.dbs["app-db-2"].name
    db_hostname                          = local.db_cluster.db_cluster.host
    db_port                              = local.db_cluster.db_cluster.port
  }
}

# ------------------------------------------------------------------------------
# FIREWALL FOR DB ACCESS SERVER
# ------------------------------------------------------------------------------
resource "digitalocean_firewall" "db_access_server_firewall" {
  name = "${terraform.workspace}-db-access-server-firewall"

  droplet_ids = [module.db_access_server.id]

  # Only inbound TCP traffic from application server allowed
  inbound_rule {
    protocol           = "tcp"
    port_range         = "1-65535"
    source_droplet_ids = [module.application_server.id]
  }
}
