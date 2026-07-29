# ==============================================================================
# 1. STATE & BACKEND
# ==============================================================================
terraform {
  backend "azurerm" {}
}

# ------------------------------------------------------------------------------
# 2. PROVIDERS
# ------------------------------------------------------------------------------
provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}

# ------------------------------------------------------------------------------
# 3. CORE INFRASTRUCTURE
# ------------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.azure_location
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.cluster_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.cluster_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_address_prefix]
}

module "aks_cluster" {
  source = "../../../modules/aks/cluster"

  cluster_name        = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_count          = var.node_count
  node_vm_size        = var.node_vm_size
  kubernetes_version  = var.kubernetes_version
  subnet_id           = azurerm_subnet.aks.id
  dns_prefix          = var.cluster_name
}
