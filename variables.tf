variable "do_region" {
  default     = "fra1"
  description = "Region to place DigitalOcean resources in"
}

variable "do_api_token" {
  type        = string
  description = "API token for DigitalOcean to manage resources"
}

variable "authorized_ssh_keys" {
  type        = list(string)
  default     = []
  description = "List of names for registered SSH keys (in DigitalOcean) that should have SSH access to the deployed VMs"
}

variable "aws_access_key_id" {
  type        = string
  description = "Access key ID to be used on deployed VMs to access AWS resources/services (e.g. S3 buckets and ECR) during operation"
}

variable "aws_secret_access_key" {
  type        = string
  description = "Secret access key to be used on deployed VMs to access AWS resources/services (e.g. S3 buckets and ECR) during operation"
}
