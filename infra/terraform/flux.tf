###############################################################################
# GitOps bootstrap. The AKS Flux extension installs the Flux controllers; the
# flux configuration points them at clusters/<environment> in this repository.
# Everything after that point (controllers, policies, tenants, apps) is
# reconciled from Git, not from Terraform.
###############################################################################

resource "azurerm_kubernetes_cluster_extension" "flux" {
  count = var.gitops.enabled ? 1 : 0

  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.this.id
  extension_type = "microsoft.flux"

  configuration_settings = {
    # Platform-level Kustomizations and HelmReleases are owned by the platform
    # team and need cluster scope. Tenant isolation is enforced through
    # namespace RBAC and Gatekeeper instead (docs/adr/0002).
    "multiTenancy.enforce" = "false"

    "helm-controller.enabled"             = "true"
    "source-controller.enabled"           = "true"
    "kustomize-controller.enabled"        = "true"
    "notification-controller.enabled"     = "true"
    "image-automation-controller.enabled" = "false"
    "image-reflector-controller.enabled"  = "false"
  }
}

resource "azurerm_kubernetes_flux_configuration" "cluster" {
  count = var.gitops.enabled ? 1 : 0

  # The GitRepository source created in-cluster takes this name; the
  # Kustomizations under clusters/ reference it as `cluster-config`.
  name       = "cluster-config"
  cluster_id = azurerm_kubernetes_cluster.this.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url                      = var.gitops.repository_url
    reference_type           = "branch"
    reference_value          = var.gitops.branch
    sync_interval_in_seconds = var.gitops.sync_interval_in_seconds
    timeout_in_seconds       = 120
  }

  kustomizations {
    name                       = "cluster"
    path                       = "./clusters/${var.environment}"
    sync_interval_in_seconds   = var.gitops.sync_interval_in_seconds
    garbage_collection_enabled = true
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}
