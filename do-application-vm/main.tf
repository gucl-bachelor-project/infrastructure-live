# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DIGITALOCEAN DROPLET (VM) WITH STANDARD USER AND APPLICATION CONFIG TO RUN DOCKERIZED APPLICATION WITH IMAGES
# LOCATED IN AMAZON ECR AND DOCKER-COMPOSE FILES LOCATED IN S3 BUCKET.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# DEPLOY DROPLET (VM)
# ------------------------------------------------------------------------------
resource "digitalocean_droplet" "droplet" {
  name               = var.vm_name
  tags               = var.tags
  image              = data.digitalocean_droplet_snapshot.base_snapshot.id
  region             = var.do_region
  size               = var.do_vm_size
  private_networking = true
  user_data          = data.template_cloudinit_config.init_config.rendered
  ssh_keys = [
    for ssh_key in var.authorized_ssh_keys :
    ssh_key.id
  ]
}

# ------------------------------------------------------------------------------
# FETCH BAKED OS IMAGE TO BOOT VM ON
# ------------------------------------------------------------------------------
data "digitalocean_droplet_snapshot" "base_snapshot" {
  name_regex  = "^gkc-bproject-packer"
  region      = "fra1"
  most_recent = true
}
