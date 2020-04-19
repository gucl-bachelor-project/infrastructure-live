output "business_logic_vm_ip" {
  value       = module.business_logic_vm.ipv4_address
  description = "IPv4 of business logic VM"
}

output "db_access_vm_ip" {
  value       = module.db_access_vm.ipv4_address
  description = "IPv4 of DB access VM"
}
