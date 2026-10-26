# Placeholder values only. Replace the GUIDs with your own subscription and
# Entra ID group before planning.
subscription_id = "00000000-0000-0000-0000-000000000000"
environment     = "prod"
location        = "westeurope"
location_short  = "weu"

kubernetes_version = "1.34"
sku_tier           = "Standard"

private_cluster_enabled = true

admin_group_object_ids = ["22222222-2222-2222-2222-222222222222"]

system_node_pool = {
  vm_size   = "Standard_D4ds_v5"
  min_count = 3
  max_count = 5
  zones     = ["1", "2", "3"]
}

user_node_pools = {
  apps = {
    vm_size   = "Standard_D8ds_v5"
    min_count = 3
    max_count = 15
    max_surge = "20%"
  }
}

network = {
  vnet_address_space  = "10.50.0.0/16"
  nodes_subnet_prefix = "10.50.0.0/22"
}

monitoring = {
  enabled        = true
  retention_days = 90
}

gitops = {
  repository_url = "https://github.com/contoso/aks-gitops-platform"
  branch         = "main"
}

workload_identities = {
  external-dns = {
    namespace       = "external-dns"
    service_account = "external-dns"
  }
}

tags = {
  cost-center = "platform-engineering"
}
