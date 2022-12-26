# Create resource group name using the Azure CAF provider
resource "azurecaf_name" "resource_group" {
  name          = var.name
  resource_type = "azurerm_resource_group"
  suffixes      = [var.environment_type, module.azure_region.location_short]
  clean_input   = true
}

# Create the resource group
resource "azurerm_resource_group" "resource_group" {
  name     = azurecaf_name.resource_group.result
  location = var.location
  tags     = var.default_tags
}
