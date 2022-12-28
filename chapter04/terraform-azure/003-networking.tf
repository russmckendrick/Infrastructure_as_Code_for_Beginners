# Create Virtual Network name using the Azure CAF Module
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

# Create Load Balancer name using the Azure CAF Module
resource "azurecaf_name" "load_balancer" {
  name          = var.name
  resource_type = "azurerm_lb"
  suffixes      = [var.environment_type, module.azure_region.location_short]
  clean_input   = true
}

# Create Load Balancer name using the Azure CAF Module
resource "azurecaf_name" "load_balancer_pip" {
  name          = azurecaf_name.load_balancer.result
  resource_type = "azurerm_public_ip"
  clean_input   = true
}


# Create NSG name using the Azure CAF Module
resource "azurecaf_name" "nsg" {
  name          = var.name
  resource_type = "azurerm_network_security_group"
  suffixes      = [var.environment_type, module.azure_region.location_short]
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


resource "azurerm_public_ip" "load_balancer" {
  name                = azurecaf_name.load_balancer_pip.result
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  allocation_method   = "Static"
  tags                = var.default_tags
}

resource "azurerm_lb" "load_balancer" {
  name                = azurecaf_name.load_balancer.result
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  tags                = var.default_tags

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.load_balancer.id
  }
}

resource "azurerm_lb_backend_address_pool" "load_balancer" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "http_load_balancer_probe" {
  loadbalancer_id = azurerm_lb.load_balancer.id
  name            = "http-running-probe"
  port            = 80
}

resource "azurerm_lb_rule" "http_load_balancer_rule" {
  loadbalancer_id                = azurerm_lb.load_balancer.id
  name                           = "HTTPRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.http_load_balancer_probe.id
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.load_balancer.id
  ]
}

resource "azurerm_lb_nat_rule" "sshAccess" {
  resource_group_name            = azurerm_resource_group.resource_group.name
  loadbalancer_id                = azurerm_lb.load_balancer.id
  name                           = "sshAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 2222
  frontend_port_end              = 2232
  backend_port                   = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.load_balancer.id
  frontend_ip_configuration_name = "PublicIPAddress"
}

# Create Network Security Group for Linux VMs
resource "azurerm_network_security_group" "nsg" {
  name                = azurecaf_name.nsg.result
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  tags                = var.default_tags
}

resource "azurerm_network_security_rule" "AllowHTTP" {
  name                        = "AllowHTTP"
  description                 = "Allow HTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "AllowSSH" {
  name                        = "AllowSSH"
  description                 = "Allow SSH"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_address_prefixes     = setunion(var.sa_network_trusted_ips, ["${jsondecode(data.http.current_ip.response_body).ip}"])
  source_port_range           = "*"
  destination_port_range      = "22"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate the NSG to the subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.vnet_subnets["${var.subnet_for_vms}"].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
