variable "region_aws" {
  description = "La región de AWS donde se desplegarán los recursos."
  type        = string
  default     = "us-east-1"
}

variable "region_azure" {
  description = "La región de Azure donde se desplegarán los recursos."
  type        = string
  default     = "East US"
}

variable "ResourceGroupName" {
  description = "Nombre de Grupo de Recursos de Azure"
  type        = string
  default     = "Monex_Lab"
}

variable "subnets_aro" {
  default = {
    snet-aro-prod-scus3 = "10.61.0.128/25"
    snet-solace-prod-scus1 = "10.61.1.0/25"
    snet-aro-prod-scus2 = "10.61.1.128/25"
    snet-aro-prod-scus1 = "10.61.2.0/25"
    snet-aro-prod-scus7 = "10.61.2.128/25"
  }
}

variable "route_tables" {
  description = "Mapa de tablas de ruteo y sus rutas"
  default = {
    rt1 = {
      route_name       = "route1"
      address_prefix   = "10.1.0.0/16"
      next_hop_type    = "VnetLocal"
    }
    rt2 = {
      route_name       = "route2"
      address_prefix   = "10.2.0.0/16"
      next_hop_type    = "VnetLocal"
    }
  }
}

