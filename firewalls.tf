resource "digitalocean_firewall" "base_vm_firewall" {
    name = "${terraform.workspace}-base-vm-firewall"

    droplet_ids = [module.business_logic_vm.id, module.db_access_vm.id]

    # All SSH access allowed
    inbound_rule {
        protocol         = "tcp"
        port_range       = "22"
        source_addresses = ["0.0.0.0/0", "::/0"]
    }

    # All outbound TCP/UDP/ICMP traffic traffic
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

resource "digitalocean_firewall" "business_logic_app_firewall" {
    name = "${terraform.workspace}-business-logic-app-firewall"

    droplet_ids = [module.business_logic_vm.id]

    # All inbound TCP traffic allowed
    inbound_rule {
        protocol         = "tcp"
        port_range       = "80"
        source_addresses = ["0.0.0.0/0", "::/0"]
    }
}

resource "digitalocean_firewall" "db_access_app_firewall" {
    name = "${terraform.workspace}-db-access-app-firewall"

    droplet_ids = [module.db_access_vm.id]

    # Only inbound TCP traffic allowed for 
    inbound_rule {
        protocol           = "tcp"
        port_range         = "1-65535"
        source_droplet_ids = [module.business_logic_vm.id]
    }
}
