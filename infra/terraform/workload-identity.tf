###############################################################################
# Platform workload identities. Each entry creates a user-assigned identity
# federated with one Kubernetes service account, e.g. external-dns or
# cert-manager (DNS-01). Team identities follow the same pattern from their
# own stacks; the platform/ namespace template wires the service account side.
###############################################################################

resource "azurerm_user_assigned_identity" "workload" {
  for_each = var.workload_identities

  name                = "id-${each.key}-${local.name_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "workload" {
  for_each = var.workload_identities

  name                = "fic-${each.key}"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.workload[each.key].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account}"
}
