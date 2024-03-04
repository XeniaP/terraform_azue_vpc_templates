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