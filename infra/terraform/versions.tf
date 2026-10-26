terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58"
    }
  }

  # Partial configuration: supply the storage account details at init time,
  # e.g. `terraform init -backend-config=environments/dev.backend.hcl`.
  backend "azurerm" {}
}
