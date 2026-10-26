data "azurerm_client_config" "current" {}

locals {
  name_suffix = "${var.name_prefix}-${var.environment}-${var.location_short}"

  tags = merge(
    {
      environment = var.environment
      managed-by  = "terraform"
      workload    = "aks-gitops-platform"
    },
    var.tags,
  )
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_suffix}"
  location = var.location
  tags     = local.tags
}

###############################################################################
# Networking: one VNet, one node subnet. Pods get overlay IPs (Azure CNI
# Overlay), so the subnet only has to size for nodes.
###############################################################################

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.network.vnet_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.network.nodes_subnet_prefix]
}

###############################################################################
# Control plane identity. User-assigned so it exists before the cluster and
# can be granted rights on the BYO subnet without a chicken-and-egg problem.
###############################################################################

resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-aks-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "control_plane_network" {
  scope                = azurerm_subnet.nodes.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}
