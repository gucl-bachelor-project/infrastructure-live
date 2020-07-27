variable "do_region" {
  default     = "fra1"
  description = "Region to place DigitalOcean resources in"
}

variable "do_api_token" {
  type        = string
  description = "API token for DigitalOcean to manage resources"
}

variable "do_spaces_access_key_id" {
  type        = string
  description = "" # TODO
}

variable "do_spaces_secret_access_key" {
  type        = string
  description = "" # TODO
}

variable "pvt_key" {
  type        = string
  description = "" # TODO
}