# Placeholder values only. Replace the GUIDs with your own subscription and
# Entra ID group before planning.
subscription_id = "00000000-0000-0000-0000-000000000000"
environment     = "dev"
location        = "westeurope"
location_short  = "weu"

kubernetes_version = "1.34"
sku_tier           = "Free"

# Dev keeps a public, IP-restricted API server so CI and engineers can reach
# it without private connectivity.
private_cluster_enabled         = false
api_server_authorized_ip_ranges = ["203.0.113.0/24"]

admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]

system_node_pool = {
  vm_size   = "Standard_D2ds_v5"
  min_count = 1
  max_count = 3
  zones     = ["1"]
}

user_node_pools = {
  apps = {
    vm_size   = "Standard_D4ds_v5"
    min_count = 1
    max_count = 5
    zones     = ["1"]
  }
}

network = {
  vnet_address_space  = "10.40.0.0/16"
  nodes_subnet_prefix = "10.40.0.0/22"
}

monitoring = {
  enabled        = false
  retention_days = 30
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
