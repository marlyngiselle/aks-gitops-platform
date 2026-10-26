# Architecture

The platform has two halves with a hard boundary between them.

| Half | Owned by | Tool | Changes when |
| --- | --- | --- | --- |
| Azure resources (network, cluster, node pools, identities, monitoring, Flux bootstrap) | Platform team | Terraform, `infra/terraform` | Capacity, versions or cluster features change |
| Everything inside the cluster (add-ons, policies, tenants, apps) | Platform team and product teams | Flux, everything outside `infra/` | Any merge to `main` |

Terraform stops at the point where Flux can take over. It never runs `helm` or `kubectl`, and Flux never touches Azure resources. That keeps state in one place per object and makes the cluster rebuildable from two inputs, the Terraform variables and this repository.

## Azure resources

```mermaid
flowchart LR
  subgraph rg["Resource group rg-idp-&lt;env&gt;-weu"]
    direction TB
    vnet["VNet<br/>snet-aks-nodes"]
    idcp["User-assigned identity<br/>(control plane)"]
    idwl["User-assigned identities<br/>(platform workloads)"]
    law["Log Analytics + DCR<br/>(optional)"]
    subgraph aks["AKS cluster"]
      direction TB
      api["API server<br/>private endpoint or IP allow-list"]
      sys["system pool<br/>CriticalAddonsOnly, zones 1-3"]
      usr["user pools<br/>autoscaling, zones 1-3"]
      flux["Flux extension<br/>microsoft.flux"]
      oidc["OIDC issuer +<br/>workload identity"]
      kv["Key Vault CSI driver"]
    end
  end
  entra["Entra ID groups"] -- "Azure RBAC" --> api
  idcp -- "Network Contributor" --> vnet
  oidc -- "federated credentials" --> idwl
  aks -- "Container Insights" --> law
  git["Git repository<br/>clusters/&lt;env&gt;"] -- "pull" --> flux
```

### Decisions encoded in Terraform

| Area | Choice | Why |
| --- | --- | --- |
| API server | `private_cluster_enabled` toggle; public mode requires an IP allow-list | Prod is private. Dev can stay public but never open to the internet |
| Authentication | Entra ID with Azure RBAC, `local_account_disabled = true` | No static admin kubeconfig exists to leak; access is revoked by removing a group membership |
| Workload auth | OIDC issuer and workload identity enabled; `var.workload_identities` creates federated identities | Pods get Entra tokens without client secrets |
| Networking | Azure CNI Overlay, Cilium dataplane and network policy | Pods do not consume VNet addresses, so the node subnet stays small; Cilium enforces the default-deny policies of the tenant template |
| Node pools | System pool tainted `CriticalAddonsOnly`, user pools for workloads, all autoscaled and zonal, ephemeral OS disks | A noisy tenant cannot starve CoreDNS or the Flux controllers |
| Upgrades | `patch` auto-upgrade channel, `NodeImage` OS channel, weekly maintenance window | Patches and CVE fixes land automatically; minor versions stay a reviewed change (see [upgrade strategy](upgrade-strategy.md)) |
| Monitoring | Container Insights toggle, managed identity auth, data collection rule with ContainerLogV2 | Logs and inventory in Azure Monitor; metrics stay in-cluster with Prometheus |
| Secrets | Key Vault CSI driver add-on with rotation | Secrets are mounted from Key Vault, never committed |
| Policy | Azure Policy add-on disabled | Gatekeeper is installed by Flux instead ([ADR 0003](adr/0003-gatekeeper-via-flux.md)) |

## Inside the cluster

Flux reconciles `clusters/<env>`, which declares six Flux Kustomizations in four layers. Each layer waits for the previous one to become healthy.

```mermaid
flowchart TB
  subgraph L1["1. Infrastructure"]
    ic["infra-controllers<br/>ingress-nginx, cert-manager,<br/>kube-prometheus-stack, Gatekeeper,<br/>external-dns (prod)"]
    cfg["infra-configs<br/>ClusterIssuers, PodMonitors"]
  end
  subgraph L2["2. Policies"]
    pt["policy-templates<br/>ConstraintTemplates"]
    pc["policy-constraints<br/>dryrun in dev, deny in prod"]
  end
  subgraph L3["3. Platform"]
    pl["platform-tenants<br/>one namespace per team"]
  end
  subgraph L4["4. Apps"]
    ap["apps<br/>team workloads"]
  end
  ic --> cfg
  ic --> pt --> pc
  cfg --> pl
  pc --> pl
  pl --> ap
```

| Layer | Path | Contents |
| --- | --- | --- |
| Infrastructure | `infrastructure/controllers/<env>`, `infrastructure/configs` | Helm releases for shared add-ons, then objects that need their CRDs |
| Policies | `policies/templates`, `policies/constraints/<env>` | Gatekeeper templates, then constraints. Two steps because each template registers the CRD its constraint needs |
| Platform | `platform/teams` | Tenant namespaces rendered from `platform/components/team-namespace` |
| Apps | `apps/<env>` | Team workloads, here the podinfo sample |

### Tenant boundary

Every tenant namespace is rendered from the same component and gets the same guardrails.

```mermaid
flowchart LR
  subgraph ns["Namespace team-&lt;name&gt; (tier=tenant)"]
    rq["ResourceQuota"]
    lr["LimitRange defaults"]
    np["NetworkPolicies<br/>default deny + DNS,<br/>same namespace, ingress-nginx,<br/>Prometheus scrape"]
    rb["RoleBinding: edit<br/>to the team's Entra group"]
    sa["ServiceAccount workload<br/>workload identity client ID"]
  end
  gk["Gatekeeper constraints<br/>match tier=tenant"] -.-> ns
  pss["Pod Security Admission<br/>enforce baseline, warn restricted"] -.-> ns
```

Admission runs in this order for a tenant pod: the LimitRange injects default resources, Pod Security Admission checks the baseline profile, and Gatekeeper checks registries, privilege and resources. A workload that relies on the defaults still passes the resource constraint.

## What is deliberately out of scope

- Application CI and image builds. Teams push images to the platform registry; this repository only deploys them.
- Secrets content. The Key Vault CSI driver and workload identity are wired up, Key Vaults and their secrets belong to each team's own infrastructure.
- Multi-cluster fleet management. Two environments are enough to show the overlay model; more clusters follow the same `clusters/<name>` pattern.
