###############################################################################
# Container Insights (optional). Uses managed identity auth and a data
# collection rule, with ContainerLogV2 schema.
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  count = var.monitoring.enabled ? 1 : 0

  name                = "log-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.monitoring.retention_days
  tags                = local.tags
}

resource "azurerm_monitor_data_collection_rule" "container_insights" {
  count = var.monitoring.enabled ? 1 : 0

  name                = "dcr-ci-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  destinations {
    log_analytics {
      name                  = "ciworkspace"
      workspace_resource_id = azurerm_log_analytics_workspace.this[0].id
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  count = var.monitoring.enabled ? 1 : 0

  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights[0].id
}
