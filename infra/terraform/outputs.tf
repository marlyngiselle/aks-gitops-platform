output "resource_group_name" {
  description = "Resource group that holds the cluster."
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "node_resource_group" {
  description = "Managed resource group that holds the node resources."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used as the issuer of federated identity credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet identity (grant AcrPull on the registry to this principal)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "key_vault_secrets_provider_client_id" {
  description = "Client ID of the Key Vault CSI driver identity, or null when the add-on is disabled."
  value       = try(azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].client_id, null)
}

output "workload_identity_client_ids" {
  description = "Client IDs of the platform workload identities, keyed like var.workload_identities. Use them in the `azure.workload.identity/client-id` service account annotation."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID, or null when Container Insights is disabled."
  value       = try(azurerm_log_analytics_workspace.this[0].id, null)
}

output "flux_configuration_name" {
  description = "Name of the Flux configuration (and of the in-cluster GitRepository source)."
  value       = try(azurerm_kubernetes_flux_configuration.cluster[0].name, null)
}

output "get_credentials_command" {
  description = "Fetch a kubeconfig that authenticates through Entra ID (requires kubelogin)."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name} && kubelogin convert-kubeconfig -l azurecli"
}
