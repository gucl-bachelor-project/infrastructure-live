output "application_server_ip" {
  value       = module.application_server.ipv4_address
  description = "IPv4 address of application server"
}

output "db_access_server_ip" {
  value       = module.db_access_server.ipv4_address
  description = "IPv4 address of DB access server"
}
