# Envionment Variables
######################################################################################################
variable "name" {
  description = "Base name for resources"
  default     = "iac-wordpress"
}

variable "location" {
  description = "Which region in Azure are we launching the resources"
  default     = "UK South"
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
  description = "The subnets to deplooy in the vnet"
  type = map(object({
    subnet_name                               = string
    address_prefix                            = string
    private_endpoint_network_policies_enabled = bool
  }))
  default = {
    virtual_network_subnets_001 = {
      subnet_name                               = "appgw"
      address_prefix                            = "10.0.0.0/27"
      private_endpoint_network_policies_enabled = true
    },
    virtual_network_subnets_002 = {
      subnet_name                               = "vms"
      address_prefix                            = "10.0.0.32/27"
      private_endpoint_network_policies_enabled = true
    },
    virtual_network_subnets_003 = {
      subnet_name                               = "endpoints"
      address_prefix                            = "10.0.0.64/27"
      private_endpoint_network_policies_enabled = true
    },
  }
}
