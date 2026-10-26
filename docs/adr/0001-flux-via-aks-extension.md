# 0001. Bootstrap Flux through the AKS cluster extension

Status: Accepted

## Context

The cluster needs a GitOps controller from the first minute, before anyone can reach the API server of a private cluster. The options considered were `flux bootstrap` from a workstation or pipeline, Argo CD installed by Terraform through the Helm provider, and the `microsoft.flux` AKS extension managed by `azurerm_kubernetes_flux_configuration`.

## Decision

Use the AKS Flux extension, created by Terraform together with the cluster.

## Consequences

- Bootstrap needs only the Azure Resource Manager API. It works for a private cluster without VPN access from CI, because Terraform never talks to the Kubernetes API.
- Terraform owns exactly two GitOps objects, the extension and one flux configuration pointing at `clusters/<env>`. Everything else is in Git.
- Microsoft operates the Flux controller lifecycle. Flux versions follow the extension's release train, which can lag upstream Flux by some weeks.
- The extension enforces Flux multi-tenancy by default. It is turned off (`multiTenancy.enforce = false`) because the platform layers are cluster-scoped by nature; tenant isolation comes from namespace RBAC and Gatekeeper ([ADR 0002](0002-namespace-as-a-service.md)).
- Argo CD's UI is not available. `kubectl get kustomizations,helmreleases -A`, Flux events and the Azure portal's GitOps view cover the same need for a platform team.
