variable "do_region" {
  default     = "fra1"
  description = "Region to locate DigitalOcean resources in"
}

variable "do_api_token" {
  type        = string
  description = "API token for DigitalOcean to manage resources"
}

variable "ssh_public_key_path" {
  default     = null // Optional
  description = "Local path to SSH key on your computer (example: /Users/<username>/.ssh/id_rsa.pub). Used if you wish to grant SSH access to deployed VMs in the development environment."
}

variable "aws_access_key_id" {
  type        = string
  description = "Access key ID to be used on deployed VMs to access AWS resources/services (e.g. S3 buckets and ECR) during operation"
}

variable "aws_secret_access_key" {
  type        = string
  description = "Secret access key to be used on deployed VMs to access AWS resources/services (e.g. S3 buckets and ECR) during operation"
}
