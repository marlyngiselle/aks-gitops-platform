provider "azurerm" {
  subscription_id = var.subscription_id

  # Role assignments and the Flux extension rely on Entra ID auth; keep
  # resource provider registration explicit and under platform control.
  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.ContainerService",
    "Microsoft.KubernetesConfiguration",
    "Microsoft.OperationalInsights",
  ]

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
