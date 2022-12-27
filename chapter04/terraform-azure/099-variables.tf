# Envionment Variables
######################################################################################################
variable "name" {
  description = "Base name for resources"
  default     = "iac-wordpress"
}

variable "location" {
  description = "Which region in Azure are we launching the resources"
  default     = "West Europe"
}

variable "environment_type" {
  description = "type of the environment we are building"
  default     = "prod"
}

variable "default_tags" {
  description = "The default tags to use across all of our resources"
  type        = map(any)
  default = {
    project     = "iac-wordpress"
    environment = "prod"
    deployed_by = "terraform"
  }
}

# Networking Variables
######################################################################################################
variable "vnet_address_space" {
  description = "The address space of vnet"
  default     = "10.0.0.0/24"
}

variable "vnet_subnets" {
  description = "The subnets to deploy in the vnet"
  type = map(object({
    subnet_name                               = string
    address_prefix                            = string
    private_endpoint_network_policies_enabled = bool
    service_endpoints                         = list(string)
    service_delegations                       = map(map(list(string)))
  }))
  default = {
    virtual_network_subnets_001 = {
      subnet_name                               = "vms"
      address_prefix                            = "10.0.0.0/27"
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Storage"]
      service_delegations                       = {}
    },
    virtual_network_subnets_002 = {
      subnet_name                               = "endpoints"
      address_prefix                            = "10.0.0.32/27"
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Storage"]
      service_delegations                       = {}
    },
    virtual_network_subnets_003 = {
      subnet_name                               = "database"
      address_prefix                            = "10.0.0.64/27"
      private_endpoint_network_policies_enabled = true
      service_endpoints                         = ["Microsoft.Storage"]
      service_delegations = {
        fs = {
          "Microsoft.DBforMySQL/flexibleServers" = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
    },
  }
}

variable "subnet_for_endpoints" {
  description = "Reference to put the private endpoint in"
  default     = "virtual_network_subnets_002"
}

variable "subnet_for_database" {
  description = "Reference to put the private endpoint in"
  default     = "virtual_network_subnets_003"
}

# Storeage Variables
######################################################################################################

variable "sa_account_tier" {
  description = "What tier of storage account do we want to deploy"
  default     = "Premium"
}

variable "sa_account_replication_type" {
  description = "What type of replication do we want to use"
  default     = "LRS"
}

variable "sa_enable_https_traffic_only" {
  description = "Do we want to enable https traffic only"
  type        = bool
  default     = false
}

variable "sa_min_tls_version" {
  description = "What is the minimum TLS version we want to use"
  default     = "TLS1_2"
}

variable "sa_trusted_ips" {
  description = "Optional list if IP addresses which need access, your current IP will be added automatically"
  default = [
  ]
}
