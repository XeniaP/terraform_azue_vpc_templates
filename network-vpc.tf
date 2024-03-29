provider "aws" {
  region = var.region_aws
  # Tus credenciales de AWS pueden ser configuradas mediante variables de entorno.
}

provider "azurerm" {
  features {}
  # Tus credenciales de Azure pueden ser configuradas mediante variables de entorno o mediante login de Azure CLI.
}

# Recursos Azure
resource "azurerm_resource_group" "resourceGroup" {
  name     = var.ResourceGroupName
  location = var.region_azure

  tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_virtual_network" "vnet_hub_vpn"{
    name                = "vpn_hub_gateway"
    address_space       =["10.0.0.0/16"]
    location            = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_subnet" "gw_subnet" {
    name                    = "GatewaySubnet"
    resource_group_name     = azurerm_resource_group.resourceGroup.name
    virtual_network_name    = azurerm_virtual_network.vnet_hub_vpn.name
    address_prefixes        = ["10.0.254.0/24"]
}

resource "azurerm_subnet" "default_subnet" {
    name                    = "Subnet1"
    resource_group_name     = azurerm_resource_group.resourceGroup.name
    virtual_network_name    = azurerm_virtual_network.vnet_hub_vpn.name
    address_prefixes        = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "vnet_gw_ip" {
    name                    = "gateway_subnet_ip"
    location                = azurerm_resource_group.resourceGroup.location
    resource_group_name     = azurerm_resource_group.resourceGroup.name
    allocation_method       = "Dynamic"

    tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_virtual_network_gateway" "az_net_gw" {
    name = "az_network_gw"
    location                = azurerm_resource_group.resourceGroup.location
    resource_group_name     = azurerm_resource_group.resourceGroup.name
    type = "Vpn"
    vpn_type = "RouteBased"
    active_active = false
    enable_bgp = false
    sku = "VpnGw1"

    ip_configuration {
        name = "az_network_gw_config"
        public_ip_address_id = azurerm_public_ip.vnet_gw_ip.id
        private_ip_address_allocation = "Dynamic"
        subnet_id = azurerm_subnet.gw_subnet.id
    }

    depends_on = [ azurerm_public_ip.vnet_gw_ip ]
}

#Recursos AWS 
resource "aws_vpc" "private_aws_vpc" {
    cidr_block           = "192.168.0.0/16"
    enable_dns_support   = true
    enable_dns_hostnames = true

    tags = {
        Name = "vpn_vpc"
        environment = "Monex_Lab"
    }
}

resource "aws_subnet" "pri_vpc_subnet1" {
    vpc_id = aws_vpc.private_aws_vpc.id
    cidr_block = "192.168.0.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "private_vpc_subnet1"
        environment = "Monex_Lab"
    }
}

resource "aws_internet_gateway" "private_vpc_internet_gw" {
    vpc_id = aws_vpc.private_aws_vpc.id
    
    tags = {
        Name = "priv_vpc_igw"
        environment = "Monex_Lab"
    }
}

resource "aws_customer_gateway" "customer_gw_to_azure" {
    bgp_asn = "65000"
    ip_address = azurerm_public_ip.vnet_gw_ip.ip_address
    type = "ipsec.1"

    tags = {
        Name = "customer_gw_to_azure"
        environment = "Monex_Lab"
    }

    depends_on = [
        azurerm_public_ip.vnet_gw_ip, azurerm_virtual_network_gateway.az_net_gw
    ]
}

resource "aws_vpn_gateway" "private_gw_to_azure" {
    vpc_id = aws_vpc.private_aws_vpc.id
    tags = {
        Name = "private_gw_to_azure"
        environment = "Monex_Lab"
    }
}

resource "aws_vpn_connection" "vpn_connection" {
    customer_gateway_id = aws_customer_gateway.customer_gw_to_azure.id
    vpn_gateway_id      = aws_vpn_gateway.private_gw_to_azure.id
    type                = "ipsec.1"
    static_routes_only  = true

    tags = {
        Name = "vpn_connection"
        environment = "Monex_Lab"
    }
}

resource "aws_vpn_connection_route" "default" {
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
  destination_cidr_block = "10.0.0.0/24"
}

#Configuracion de comunicacion 
resource "azurerm_local_network_gateway" "local_net_gw1" {
    name = "local_net_gw1"
    location = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    gateway_address = aws_vpn_connection.vpn_connection.tunnel1_address
    address_space = ["192.168.0.0/16"]

    tags = {
        Name = "local_net_gw1"
        environment = "Monex_Lab"
    }
}

resource "azurerm_virtual_network_gateway_connection" "local_net_gw1_connection" {
    name = "local_net_gw1_connection"
    location = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    type = "IPsec"
    virtual_network_gateway_id = azurerm_virtual_network_gateway.az_net_gw.id
    local_network_gateway_id = azurerm_local_network_gateway.local_net_gw1.id

    shared_key = aws_vpn_connection.vpn_connection.tunnel1_preshared_key

    tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_local_network_gateway" "local_net_gw2" {
    name = "local_net_gw2"
    location = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    gateway_address = aws_vpn_connection.vpn_connection.tunnel2_address
    address_space = ["192.168.0.0/16"]

    tags = {
        Name = "local_net_gw2"
        environment = "Monex_Lab"
    }
}

resource "azurerm_virtual_network_gateway_connection" "local_net_gw2_connection" {
    name = "local_net_gw2_connection"
    location = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    type = "IPsec"
    virtual_network_gateway_id = azurerm_virtual_network_gateway.az_net_gw.id
    local_network_gateway_id = azurerm_local_network_gateway.local_net_gw2.id

    shared_key = aws_vpn_connection.vpn_connection.tunnel2_preshared_key

    tags = {
        environment = "Monex_Lab"
    }
}

resource "aws_route_table" "priv_vpc_rt" {
    vpc_id = aws_vpc.private_aws_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.private_vpc_internet_gw.id
    }

    route {
        cidr_block = "10.0.0.0/24"
        gateway_id = aws_vpn_gateway.private_gw_to_azure.id
    }

    tags = {
        Name = "rt_igw"
        environment = "Monex_Lab"
    }
}

resource "aws_route_table_association" "rt_igw_association" {
    subnet_id = aws_subnet.pri_vpc_subnet1.id
    route_table_id = aws_route_table.priv_vpc_rt.id
}

#vnet workload
resource "azurerm_virtual_network" "vnet_aro"{
    name                = "aro"
    address_space       =["10.61.0.0/22"]
    location            = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_subnet" "example" {
    for_each = var.subnets_aro
    name = each.key
    resource_group_name = azurerm_resource_group.resourceGroup.name
    virtual_network_name = azurerm_virtual_network.vnet_aro.name
    address_prefixes = [each.value]
}

resource "azurerm_virtual_network" "vnet_desarrollo"{
    name                = "Desarrollo"
    address_space       =["10.7.0.0/22"]
    location            = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    tags = {
        environment = "Monex_Lab"
    }
}

resource "azurerm_subnet" "desasubnet" {
    name = "snet-dvm-desa-south-01"
    resource_group_name = azurerm_resource_group.resourceGroup.name
    virtual_network_name = azurerm_virtual_network.vnet_desarrollo.name
    address_prefixes = ["10.7.0.0/25"]
}
resource "azurerm_virtual_network" "vnet_prod"{
    name                = "Produccion"
    address_space       =["10.6.0.0/22"]
    location            = azurerm_resource_group.resourceGroup.location
    resource_group_name = azurerm_resource_group.resourceGroup.name

    tags = {
        environment = "Monex_Lab"
    }
}
resource "azurerm_subnet" "prodasubnet" {
    name = "snet-dvm-prod-south-01"
    resource_group_name = azurerm_resource_group.resourceGroup.name
    virtual_network_name = azurerm_virtual_network.vnet_prod.name
    address_prefixes = ["10.6.0.0/23"]
}


resource "azurerm_virtual_network_peering" "vpn_to_aro" {
  name                      = "vpn-to-aro"
  resource_group_name       = azurerm_resource_group.resourceGroup.name
  virtual_network_name      = azurerm_virtual_network.vnet_hub_vpn.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_aro.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_virtual_network_peering" "aro_to_vpn" {
  name                      = "aro-to-vpn"
  resource_group_name       = azurerm_resource_group.resourceGroup.name
  virtual_network_name      = azurerm_virtual_network.vnet_aro.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub_vpn.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

resource "azurerm_route_table" "vpn_hub_gateway_route_table" {
  name                = "vpn-hub-gateway-route-table"
  location            = azurerm_resource_group.resourceGroup.location
  resource_group_name = azurerm_resource_group.resourceGroup.name
}

resource "azurerm_route" "route_to_aws" {
  name                   = "route-to-aws"
  resource_group_name    = azurerm_resource_group.resourceGroup.name
  route_table_name       = azurerm_route_table.vpn_hub_gateway_route_table.name
  address_prefix         = "192.168.0.0/16" # Ejemplo: "172.31.0.0/16"
  next_hop_type          = "VirtualNetworkGateway"
}

resource "azurerm_subnet_route_table_association" "vpn_hub_gateway_subnet_association" {
  subnet_id      = azurerm_subnet.gw_subnet.id # Asegúrate de reemplazar esto con el ID de tu subnet real
  route_table_id = azurerm_route_table.vpn_hub_gateway_route_table.id
}


