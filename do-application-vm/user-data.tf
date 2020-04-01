# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CLOUD INIT CONFIG FOR VM
# To be run when the VM boots for the first time to setup VM and start application.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT FOR CONFIGURING REMOTE ACCESS TO VM
# ------------------------------------------------------------------------------
data "template_file" "vm_access_config" {
  template = file("${path.module}/init-config-templates/vm-access-config.tpl")
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT TO CONFIGURE CREDENTIALS AND OTHER SETTINGS
# IN AWS CLI PROGRAM.
# ------------------------------------------------------------------------------
data "template_file" "aws_cli_config" {
  template = file("${path.module}/init-config-templates/aws-cli-setup.tpl")

  vars = {
    aws_region            = var.aws_config.region
    aws_access_key_id     = var.aws_config.access_key_id
    aws_secret_access_key = var.aws_config.secret_access_key
  }
}

# ------------------------------------------------------------------------------
# CLOUD INIT CONFIG SCRIPT TO CONFIGURE SSH ACCESS TO VM IF AUTHORIZED
# SSH KEYS ARE SPECIFIED.
# ------------------------------------------------------------------------------
data "template_file" "vm_user_init_config" {
  template = file("${path.module}/init-config-templates/vm-user.tpl")

  vars = {
    authorized_ssh_keys = yamlencode([
      for ssh_key in var.authorized_ssh_keys :
      ssh_key.public_key
    ])
  }
}

# ------------------------------------------------------------------------------
# COMBINED/MERGED CLOUD INIT CONFIG SCRIPT WITH ALL DEFINED SCRIPTS IN
# THIS FILE.
# To be installed and run on VM during first boot.
# ------------------------------------------------------------------------------
data "template_cloudinit_config" "init_config" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "aws-cli-config.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.aws_cli_config.rendered
  }

  part {
    filename     = "vm-access-config.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.vm_access_config.rendered
  }

  part {
    filename     = "vm-user-init.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.vm_user_init_config.rendered
  }

  part {
    filename     = "app-vm-bootstrap.cfg"
    content_type = "text/cloud-config"
    content      = var.app_start_script
  }
}
