output "id" {
  value       = digitalocean_droplet.droplet.id
  description = "ID of the deployed Droplet"
}

output "urn" {
  value       = digitalocean_droplet.droplet.urn
  description = "The uniform resource name of the deployed Droplet"
}

output "ipv4_address" {
  value       = digitalocean_droplet.droplet.ipv4_address
  description = "The IPv4 address of the deployed Droplet"
}

output "private_ipv4_address" {
  value       = digitalocean_droplet.droplet.ipv4_address_private
  description = "The private IPv4 address of the deployed Droplet"
}
