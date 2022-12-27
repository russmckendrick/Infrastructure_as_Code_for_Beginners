# Create the name for the storeage account
resource "azurecaf_name" "sa" {
  name          = var.name
  resource_type = "azurerm_storage_account"
  suffixes      = [var.environment_type, module.azure_region.location_short]
  random_length = 5
  clean_input   = true
}

# Create the name for the private endpoint
resource "azurecaf_name" "sa_endpoint" {
  name          = azurecaf_name.sa.result
  resource_type = "azurerm_private_endpoint"
  clean_input   = true
}

# Create the storage account
resource "azurerm_storage_account" "sa" {
  name                      = azurecaf_name.sa.result
  resource_group_name       = azurerm_resource_group.resource_group.name
  location                  = azurerm_resource_group.resource_group.location
  account_tier              = var.sa_account_tier
  account_kind              = "FileStorage"
  account_replication_type  = var.sa_account_replication_type
  enable_https_traffic_only = var.sa_enable_https_traffic_only
  min_tls_version           = var.sa_min_tls_version
  tags                      = var.default_tags
}

# Get the IP of the current machine
data "http" "current_ip" {
  url = "https://api.ipify.org?format=json"
}

# Allow access to our storeage account from the trusted IPs and networks
resource "azurerm_storage_account_network_rules" "sa" {
  storage_account_id = azurerm_storage_account.sa.id
  default_action     = "Deny"
  ip_rules           = setunion(var.sa_trusted_ips, ["${jsondecode(data.http.current_ip.response_body).ip}"])
  virtual_network_subnet_ids = [
    for subnet_id in azurerm_subnet.vnet_subnets :
    subnet_id.id
  ]
  bypass = ["Metrics"]
}

# Create the NFS Share
resource "azurerm_storage_share" "nfs_share" {
  name                 = "sharename"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 100
  enabled_protocol     = "NFS"

  depends_on = [
    azurerm_storage_account_network_rules.sa
  ]
}

# Create the private zone for privatelink.database.windows.net
resource "azurerm_private_dns_zone" "storage_share_private_zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.resource_group.name
  tags                = var.default_tags
}

# Link the private to the vnet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_share_private_zone" {
  name                  = "link-${azurerm_virtual_network.vnet.name}"
  resource_group_name   = azurerm_resource_group.resource_group.name
  private_dns_zone_name = azurerm_private_dns_zone.storage_share_private_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
  tags                  = var.default_tags
}

# Create the Private Endpoint
resource "azurerm_private_endpoint" "storage_share_endpoint" {
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  name                = azurecaf_name.sa_endpoint.result
  subnet_id           = azurerm_subnet.vnet_subnets["${var.subnet_for_endpoints}"].id
  tags                = var.default_tags

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage_share_private_zone.id]
  }

  private_service_connection {
    name                           = azurerm_storage_account.sa.name
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }
}
