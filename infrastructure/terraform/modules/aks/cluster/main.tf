# ==============================================================================
# CORE RESOURCES - AKS CLUSTER
# ==============================================================================

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Free"  # Free mgmt tier — saves cost for portfolio/dev

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    os_disk_size_gb = 30
    vnet_subnet_id = var.subnet_id
    type           = "VirtualMachineScaleSets"
    upgrade_settings { max_surge = "10%" }
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

  lifecycle { ignore_changes = [kubernetes_version] }
}
