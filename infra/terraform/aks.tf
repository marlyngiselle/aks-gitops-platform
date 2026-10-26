resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_resource_group = "rg-${local.name_suffix}-nodes"
  dns_prefix          = "aks-${local.name_suffix}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = local.tags

  # API server exposure
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? "System" : null
  private_cluster_public_fqdn_enabled = false

  dynamic "api_server_access_profile" {
    for_each = !var.private_cluster_enabled && length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  # Identity and access: Entra ID only, authorised through Azure RBAC.
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  # Workload identity: pods exchange a projected service account token for an
  # Entra ID token. No secrets in the cluster.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Upgrades: patch versions and node images roll automatically inside the
  # maintenance window. kubernetes_version is a minor-version alias (e.g.
  # 1.34), so patch upgrades do not show up as drift; a minor upgrade is a
  # one-line change in the environment tfvars.
  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = "NodeImage"

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = var.maintenance_window.day_of_week
    start_time  = var.maintenance_window.start_time
    duration    = var.maintenance_window.duration_hours
    utc_offset  = "+00:00"
  }

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  # Policy is enforced by an upstream Gatekeeper installed through Flux (see
  # docs/adr/0003-gatekeeper-via-flux.md); the Azure Policy add-on would deploy
  # a second, conflicting Gatekeeper.
  azure_policy_enabled = false

  default_node_pool {
    name                         = "system"
    temporary_name_for_rotation  = "systemtmp"
    orchestrator_version         = var.kubernetes_version
    vm_size                      = var.system_node_pool.vm_size
    auto_scaling_enabled         = true
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    max_pods                     = var.system_node_pool.max_pods
    zones                        = var.system_node_pool.zones
    vnet_subnet_id               = azurerm_subnet.nodes.id
    os_sku                       = "AzureLinux"
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    tags                         = local.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = var.network.network_dataplane
    network_policy      = var.network.network_dataplane
    pod_cidr            = var.network.pod_cidr
    service_cidr        = var.network.service_cidr
    dns_service_ip      = var.network.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  dynamic "oms_agent" {
    for_each = var.monitoring.enabled ? [1] : []
    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.this[0].id
      msi_auth_for_monitoring_enabled = true
    }
  }

  dynamic "key_vault_secrets_provider" {
    for_each = var.key_vault_secrets_provider.enabled ? [1] : []
    content {
      secret_rotation_enabled  = var.key_vault_secrets_provider.secret_rotation_enabled
      secret_rotation_interval = var.key_vault_secrets_provider.secret_rotation_interval
    }
  }

  lifecycle {
    ignore_changes = [
      # Managed by the cluster autoscaler.
      default_node_pool[0].node_count,
    ]
  }

  depends_on = [azurerm_role_assignment.control_plane_network]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each = var.user_node_pools

  name                        = each.key
  temporary_name_for_rotation = "${substr(each.key, 0, 8)}tmp"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  orchestrator_version        = var.kubernetes_version
  mode                        = "User"
  vm_size                     = each.value.vm_size
  auto_scaling_enabled        = true
  min_count                   = each.value.min_count
  max_count                   = each.value.max_count
  max_pods                    = each.value.max_pods
  zones                       = each.value.zones
  vnet_subnet_id              = azurerm_subnet.nodes.id
  os_sku                      = each.value.os_sku
  os_disk_type                = "Ephemeral"
  node_labels                 = merge({ "platform.example.com/pool" = each.key }, each.value.node_labels)
  node_taints                 = each.value.node_taints
  tags                        = local.tags

  upgrade_settings {
    max_surge = each.value.max_surge
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}
