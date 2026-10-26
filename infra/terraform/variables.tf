###############################################################################
# Scope and naming
###############################################################################

variable "subscription_id" {
  description = "Azure subscription that hosts the cluster."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "environment" {
  description = "Deployment environment. Drives defaults, naming and the cluster overlay Flux reconciles (clusters/<environment>)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "name_prefix" {
  description = "Short workload prefix used in resource names, e.g. `idp` gives `aks-idp-dev-weu`."
  type        = string
  default     = "idp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,9}$", var.name_prefix))
    error_message = "name_prefix must be 2-10 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "westeurope"
}

variable "location_short" {
  description = "Short region code used in resource names."
  type        = string
  default     = "weu"

  validation {
    condition     = can(regex("^[a-z0-9]{2,5}$", var.location_short))
    error_message = "location_short must be 2-5 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Tags applied to every resource, merged with the module defaults."
  type        = map(string)
  default     = {}
}

###############################################################################
# Cluster
###############################################################################

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. `1.34`). Patch versions are managed by the auto-upgrade channel. Null selects the AKS default."
  type        = string
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must be a minor version such as 1.34 (no patch component)."
  }
}

variable "sku_tier" {
  description = "AKS control plane tier. `Standard` provides the uptime SLA and is expected for production."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "private_cluster_enabled" {
  description = "Expose the API server only on a private endpoint inside the VNet. Requires private connectivity (VPN, ExpressRoute or a jump host) for kubectl and CI."
  type        = bool
  default     = true
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach a public API server. Ignored when private_cluster_enabled is true."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.api_server_authorized_ip_ranges : can(cidrhost(cidr, 0))])
    error_message = "Every entry in api_server_authorized_ip_ranges must be a valid CIDR."
  }
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin through Azure RBAC. Local accounts are disabled, so at least one group is required."
  type        = list(string)

  validation {
    condition     = length(var.admin_group_object_ids) > 0
    error_message = "Provide at least one Entra ID admin group; local accounts are disabled."
  }

  validation {
    condition = alltrue([
      for id in var.admin_group_object_ids :
      can(regex("^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$", id))
    ])
    error_message = "admin_group_object_ids must contain Entra ID object IDs (GUIDs)."
  }
}

variable "automatic_upgrade_channel" {
  description = "AKS auto-upgrade channel for the control plane and nodes."
  type        = string
  default     = "patch"

  validation {
    condition     = contains(["none", "patch", "stable", "rapid", "node-image"], var.automatic_upgrade_channel)
    error_message = "automatic_upgrade_channel must be one of: none, patch, stable, rapid, node-image."
  }
}

variable "maintenance_window" {
  description = "Weekly window (UTC) during which AKS may apply automatic upgrades."
  type = object({
    day_of_week    = string
    start_time     = string
    duration_hours = number
  })
  default = {
    day_of_week    = "Sunday"
    start_time     = "02:00"
    duration_hours = 4
  }

  validation {
    condition     = contains(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"], var.maintenance_window.day_of_week)
    error_message = "maintenance_window.day_of_week must be a full English weekday name."
  }

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_window.start_time))
    error_message = "maintenance_window.start_time must use HH:MM (24h)."
  }

  validation {
    condition     = var.maintenance_window.duration_hours >= 4 && var.maintenance_window.duration_hours <= 24
    error_message = "maintenance_window.duration_hours must be between 4 and 24 (AKS minimum is 4)."
  }
}

###############################################################################
# Node pools
###############################################################################

variable "system_node_pool" {
  description = "System node pool. Tainted for critical add-ons only; application workloads land on user pools."
  type = object({
    vm_size   = optional(string, "Standard_D4ds_v5")
    min_count = optional(number, 2)
    max_count = optional(number, 4)
    max_pods  = optional(number, 110)
    zones     = optional(list(string), ["1", "2", "3"])
  })
  default = {}

  validation {
    condition     = var.system_node_pool.min_count >= 1 && var.system_node_pool.min_count <= var.system_node_pool.max_count
    error_message = "system_node_pool requires 1 <= min_count <= max_count."
  }
}

variable "user_node_pools" {
  description = "User node pools keyed by pool name (lowercase, max 12 characters)."
  type = map(object({
    vm_size     = string
    min_count   = number
    max_count   = number
    max_pods    = optional(number, 110)
    zones       = optional(list(string), ["1", "2", "3"])
    os_sku      = optional(string, "AzureLinux")
    node_labels = optional(map(string), {})
    node_taints = optional(list(string), [])
    max_surge   = optional(string, "33%")
  }))
  default = {
    apps = {
      vm_size   = "Standard_D4ds_v5"
      min_count = 2
      max_count = 10
    }
  }

  validation {
    condition     = alltrue([for name in keys(var.user_node_pools) : can(regex("^[a-z][a-z0-9]{0,11}$", name))])
    error_message = "User node pool names must be lowercase alphanumeric, start with a letter and be at most 12 characters."
  }

  validation {
    condition     = alltrue([for p in values(var.user_node_pools) : p.min_count >= 0 && p.min_count <= p.max_count])
    error_message = "Each user node pool requires 0 <= min_count <= max_count."
  }

  validation {
    condition     = alltrue([for p in values(var.user_node_pools) : contains(["AzureLinux", "Ubuntu"], p.os_sku)])
    error_message = "os_sku must be AzureLinux or Ubuntu."
  }
}

###############################################################################
# Networking
###############################################################################

variable "network" {
  description = "VNet and Azure CNI Overlay address plan. Pod and service CIDRs must not overlap the VNet or any peered network."
  type = object({
    vnet_address_space  = optional(string, "10.40.0.0/16")
    nodes_subnet_prefix = optional(string, "10.40.0.0/22")
    pod_cidr            = optional(string, "192.168.0.0/16")
    service_cidr        = optional(string, "172.16.0.0/16")
    dns_service_ip      = optional(string, "172.16.0.10")
    network_dataplane   = optional(string, "cilium")
  })
  default = {}

  validation {
    condition = alltrue([
      can(cidrhost(var.network.vnet_address_space, 0)),
      can(cidrhost(var.network.nodes_subnet_prefix, 0)),
      can(cidrhost(var.network.pod_cidr, 0)),
      can(cidrhost(var.network.service_cidr, 0)),
    ])
    error_message = "All network ranges must be valid CIDRs."
  }

  validation {
    condition     = can(cidrhost(var.network.service_cidr, 0)) && cidrhost(var.network.service_cidr, 10) == var.network.dns_service_ip
    error_message = "dns_service_ip must be the .10 address of service_cidr (AKS convention)."
  }

  validation {
    condition     = contains(["azure", "cilium"], var.network.network_dataplane)
    error_message = "network_dataplane must be azure or cilium."
  }
}

###############################################################################
# Add-ons
###############################################################################

variable "monitoring" {
  description = "Container Insights (Azure Monitor agent) settings. Prometheus metrics are handled in-cluster by kube-prometheus-stack."
  type = object({
    enabled        = optional(bool, true)
    retention_days = optional(number, 30)
  })
  default = {}

  validation {
    condition     = var.monitoring.retention_days >= 30 && var.monitoring.retention_days <= 730
    error_message = "monitoring.retention_days must be between 30 and 730."
  }
}

variable "key_vault_secrets_provider" {
  description = "Secrets Store CSI driver add-on for Azure Key Vault."
  type = object({
    enabled                  = optional(bool, true)
    secret_rotation_enabled  = optional(bool, true)
    secret_rotation_interval = optional(string, "2m")
  })
  default = {}

  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.key_vault_secrets_provider.secret_rotation_interval))
    error_message = "secret_rotation_interval must be a duration such as 2m or 1h."
  }
}

###############################################################################
# GitOps
###############################################################################

variable "gitops" {
  description = "Flux bootstrap. The cluster reconciles clusters/<environment> from this repository."
  type = object({
    enabled                  = optional(bool, true)
    repository_url           = string
    branch                   = optional(string, "main")
    sync_interval_in_seconds = optional(number, 300)
  })

  validation {
    condition     = can(regex("^(https://|ssh://)", var.gitops.repository_url))
    error_message = "gitops.repository_url must start with https:// or ssh://."
  }

  validation {
    condition     = var.gitops.sync_interval_in_seconds >= 60
    error_message = "gitops.sync_interval_in_seconds must be at least 60."
  }
}

variable "workload_identities" {
  description = "Platform workload identities keyed by short name. Each is federated with the given namespace/service account."
  type = map(object({
    namespace       = string
    service_account = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.workload_identities :
      can(regex("^[a-z0-9-]{1,40}$", k)) && can(regex("^[a-z0-9-]{1,63}$", v.namespace)) && can(regex("^[a-z0-9-]{1,253}$", v.service_account))
    ])
    error_message = "workload_identities keys, namespaces and service accounts must be lowercase DNS-style names."
  }
}
