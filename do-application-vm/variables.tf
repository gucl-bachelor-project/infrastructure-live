variable "vm_name" {
  type        = string
  description = "Name of Droplet/VM"
}

variable "tags" {
  type        = list(string)
  default     = []
  description = "List of tags to apply to Droplet"
}

variable "do_region" {
  type        = string
  description = "Name of DigitalOcean region to place Droplet in"
}

variable "do_vm_size" {
  type        = string
  description = "DigitalOcean-specified Droplet/VM size (example: s-1vcpu-1gb)"
}

variable "ssh_key" {
  type = object({
    public_key  = string
    fingerprint = string
  })
  default     = null
  description = "Authorized SSH key for remote SSH access"
}

variable "aws_config" {
  type = object({
    region            = string
    access_key_id     = string
    secret_access_key = string
  })
  description = "AWS configuration to be installed for AWS CLI program"
}

variable "app_bootstrap_config_script" {
  type        = string
  description = "Cloud-init script to be run when the VM boots"
}
