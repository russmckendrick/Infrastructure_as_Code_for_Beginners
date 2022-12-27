# Create Virtual Network using the Azure CAF Module
resource "azurecaf_name" "vnet" {
  name          = var.name
  resource_type = "azurerm_virtual_network"
  suffixes      = [var.environment_type, module.azure_region.location_short]
  clean_input   = true
}

# Create each of the subnet names using the Azure CAF provider
resource "azurecaf_name" "virtual_network_subnets" {
  for_each      = var.vnet_subnets
  name          = each.value.subnet_name
  resource_type = "azurerm_subnet"
  suffixes      = [var.name, var.environment_type, module.azure_region.location_short]
  clean_input   = true
}

# Create the Virtual Network
resource "azurerm_virtual_network" "vnet" {
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  name                = azurecaf_name.vnet.result
  address_space       = [var.vnet_address_space]
  tags                = var.default_tags
}

# Add seach of the subnets
resource "azurerm_subnet" "vnet_subnets" {
  for_each                                  = var.vnet_subnets
  name                                      = azurecaf_name.virtual_network_subnets[each.key].result
  resource_group_name                       = azurerm_resource_group.resource_group.name
  virtual_network_name                      = azurerm_virtual_network.vnet.name
  address_prefixes                          = [each.value.address_prefix]
  service_endpoints                         = try(each.value.service_endpoints, [])
  private_endpoint_network_policies_enabled = try(each.value.private_endpoint_network_policies_enabled, [])
  dynamic "delegation" {
    for_each = each.value.service_delegations
    content {
      name = delegation.key
      dynamic "service_delegation" {
        for_each = delegation.value
        iterator = item
        content {
          name    = item.key
          actions = item.value
        }
      }
    }
  }
}
