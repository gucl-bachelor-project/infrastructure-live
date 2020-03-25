# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CONFIGURE DOMAIN FOR APPLICATION
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ------------------------------------------------------------------------------
# CREATE DOMAIN IN DIGITALOCEAN IF ENVIRONMENT IS PRODUCTION OR STAGING.
# Record is created and pointed to VM in application tier receiving the
# incoming traffic from clients.
# ------------------------------------------------------------------------------
resource "digitalocean_domain" "domain" {
  count = local.environment == "development" ? 0 : 1

  name = local.environment == "production" ? data.terraform_remote_state.global.outputs.production_app_url : data.terraform_remote_state.global.outputs.staging_app_url
}

resource "digitalocean_record" "www" {
  count = local.environment == "development" ? 0 : 1

  domain = digitalocean_domain.domain[count.index].name
  type   = "A"
  name   = "@"
  value  = module.business_logic_vm.ipv4_address # TODO: Change to load balancer once available
}
