# Infrastructure – Live stack

## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.12 |
| digitalocean | ~> 1.20.0 |
| local | ~> 1.4 |
| template | ~> 2.1.2 |

## Providers

| Name | Version |
|------|---------|
| digitalocean | ~> 1.20.0 |
| template | ~> 2.1.2 |
| terraform | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| do\_api\_token | API token for DigitalOcean to manage resources | `string` | n/a | yes |
| do\_region | Region to place DigitalOcean resources in | `string` | `"fra1"` | no |
| do\_spaces\_access\_key\_id | Access key to project's DigitalOcean Spaces bucket | `string` | n/a | yes |
| do\_spaces\_secret\_access\_key | Secret key to project's DigitalOcean Spaces bucket | `string` | n/a | yes |
| pvt\_key | Path to private key on machine executing Terraform. The public key must be registered on DigitalOcean. See: https://github.com/gucl-bachelor-project/infrastructure-global/blob/master/ssh-keys.tf | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| application\_server\_ip | IPv4 address of application server |
| db\_access\_server\_ip | IPv4 address of DB access server |
