# DEV private networking for Confluent Cloud (Azure Private Link, Enterprise cluster).
#
# Separate root with its own state, so it never touches the existing DEV cluster.
# Everything is off by default and is billed while it exists:
#   1. deploy_private_networking = true  -> gateway, private endpoint, DNS, access point
#   2. deploy_private_cluster    = true  -> Enterprise cluster (hourly eCKU charge)
# Removing it later means destroying only this root.
#
# The Azure resource group is created once by hand (bootstrap) and only read here, so the
# pipeline identity needs Contributor on that one group, not on the whole subscription.

data "confluent_environment" "dev" {
  display_name = "dev"
}

locals {
  networking_enabled = var.deploy_private_networking
}

# ---- Confluent side -------------------------------------------------------

resource "confluent_gateway" "dev" {
  count = local.networking_enabled ? 1 : 0

  display_name = "dev-azure-private-link-gateway"

  environment {
    id = data.confluent_environment.dev.id
  }

  azure_ingress_private_link_gateway {
    region = var.azure_region
  }
}

# ---- Azure side -----------------------------------------------------------

data "azurerm_resource_group" "private" {
  count = local.networking_enabled ? 1 : 0

  name = var.resource_group_name
}

resource "azurerm_virtual_network" "private" {
  count = local.networking_enabled ? 1 : 0

  name                = "vnet-confluent-private-dev"
  location            = data.azurerm_resource_group.private[0].location
  resource_group_name = data.azurerm_resource_group.private[0].name
  address_space       = [var.vnet_address_space]
}

resource "azurerm_subnet" "endpoint" {
  count = local.networking_enabled ? 1 : 0

  name                 = "snet-confluent-endpoint"
  resource_group_name  = data.azurerm_resource_group.private[0].name
  virtual_network_name = azurerm_virtual_network.private[0].name
  address_prefixes     = [var.endpoint_subnet_prefix]
}

resource "azurerm_private_endpoint" "confluent" {
  count = local.networking_enabled ? 1 : 0

  name                = "pe-confluent-dev"
  location            = data.azurerm_resource_group.private[0].location
  resource_group_name = data.azurerm_resource_group.private[0].name
  subnet_id           = azurerm_subnet.endpoint[0].id

  private_service_connection {
    name                              = "confluent-dev-gateway"
    private_connection_resource_alias = confluent_gateway.dev[0].azure_ingress_private_link_gateway[0].private_link_service_alias
    is_manual_connection              = true
    request_message                   = "Confluent Cloud DEV private link"
  }
}

# ---- Register the endpoint with Confluent ---------------------------------

resource "confluent_access_point" "dev" {
  count = local.networking_enabled ? 1 : 0

  display_name = "dev-azure-private-link-access-point"

  environment {
    id = data.confluent_environment.dev.id
  }

  gateway {
    id = confluent_gateway.dev[0].id
  }

  azure_ingress_private_link_endpoint {
    private_endpoint_resource_id = azurerm_private_endpoint.confluent[0].id
  }
}

# ---- Private DNS: wildcard A record to the private endpoint ---------------

resource "azurerm_private_dns_zone" "confluent" {
  count = local.networking_enabled ? 1 : 0

  name                = confluent_access_point.dev[0].azure_ingress_private_link_endpoint[0].dns_domain
  resource_group_name = data.azurerm_resource_group.private[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "confluent" {
  count = local.networking_enabled ? 1 : 0

  name                  = "link-confluent-private-dev"
  resource_group_name   = data.azurerm_resource_group.private[0].name
  private_dns_zone_name = azurerm_private_dns_zone.confluent[0].name
  virtual_network_id    = azurerm_virtual_network.private[0].id
}

resource "azurerm_private_dns_a_record" "wildcard" {
  count = local.networking_enabled ? 1 : 0

  name                = "*"
  zone_name           = azurerm_private_dns_zone.confluent[0].name
  resource_group_name = data.azurerm_resource_group.private[0].name
  ttl                 = 60
  records             = [azurerm_private_endpoint.confluent[0].private_service_connection[0].private_ip_address]
}

# ---- Enterprise cluster on the private network ----------------------------

resource "confluent_kafka_cluster" "private" {
  count = var.deploy_private_cluster ? 1 : 0

  display_name = "kafka-dev-private"
  availability = "HIGH"
  cloud        = "AZURE"
  region       = var.azure_region

  enterprise {}

  environment {
    id = data.confluent_environment.dev.id
  }

  lifecycle {
    precondition {
      condition     = var.deploy_private_networking
      error_message = "deploy_private_cluster requires deploy_private_networking = true."
    }
  }

  depends_on = [confluent_access_point.dev]
}
