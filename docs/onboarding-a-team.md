# Onboarding a new team in 3 steps

A team gets a namespace with quota, network isolation, RBAC for its Entra ID group and a workload identity, through one pull request. No ticket to the platform team, no `kubectl`.

The example below onboards a team called `payments`. Replace the values with your own.

## Before you start

| You need | Where it comes from |
| --- | --- |
| An Entra ID group for the team's engineers | Your identity team. Its object ID goes into `entraGroupObjectId` |
| A user-assigned managed identity for the team's workloads, federated with `system:serviceaccount:team-payments:workload` | The team's own Terraform, using the cluster's `oidc_issuer_url` output |
| A cost center code | Finance. It becomes the `cost-center` label that Gatekeeper requires |

The Entra group also needs the Azure role "Azure Kubernetes Service Cluster User Role" on the cluster so its members can fetch credentials.

## Step 1. Describe the team

Create `platform/teams/payments/team-config.yaml`. This ConfigMap is an input to kustomize only (`local-config`), it is never applied to the cluster.

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: team-config
  annotations:
    config.kubernetes.io/local-config: "true"
data:
  team: payments
  costCenter: cc-2040
  entraGroupObjectId: 00000000-0000-0000-0000-000000000000
  workloadIdentityClientId: 00000000-0000-0000-0000-000000000000
  quotaCpu: "8"
  quotaMemory: 16Gi
```

## Step 2. Instantiate the namespace template

Create `platform/teams/payments/kustomization.yaml` and register the folder in `platform/teams/kustomization.yaml`.

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: team-payments
resources:
  - team-config.yaml
components:
  - ../../components/team-namespace
```

```yaml
# platform/teams/kustomization.yaml
resources:
  - podinfo
  - payments
```

Check the result locally before opening the pull request:

```bash
kustomize build platform/teams/payments
```

## Step 3. Open the pull request

CI renders every overlay and validates it. After review and merge, the `platform-tenants` layer creates the namespace on the next reconciliation. The team can then deploy its first workload by adding `apps/base/<app>` and listing it in `apps/dev` and `apps/prod`, following the podinfo example.

```bash
kubectl get kustomization platform-tenants -n flux-system
kubectl get ns team-payments --show-labels
```

## What the team gets

| Object | Effect |
| --- | --- |
| Namespace `team-payments` | Labels `team`, `cost-center`, `platform.example.com/tier: tenant`; Pod Security `baseline` enforced, `restricted` warned |
| ResourceQuota `team-quota` | CPU and memory from the config, 50 pods, 10 PVCs, no LoadBalancer or NodePort services |
| LimitRange `team-defaults` | Default requests and memory limit for containers that declare none |
| NetworkPolicies | Default deny in and out; allowed: DNS, traffic inside the namespace, ingress-nginx, Prometheus scraping |
| RoleBinding `team-edit` | Built-in `edit` role for the Entra group, in this namespace only |
| ServiceAccount `workload` | Annotated with the workload identity client ID; pods opt in with label `azure.workload.identity/use: "true"` |

Gatekeeper constraints apply to the namespace because of the `tier: tenant` label: images from allowed registries only, no privileged containers, resource requests and memory limits set, `app.kubernetes.io/name` on workloads.

## Offboarding

The `platform-tenants` layer runs with `prune: false`, so deleting the folder does not delete the namespace. Offboarding is two deliberate steps: remove the folder and its line in a pull request, then delete the namespace by hand once the team confirms its data is gone.
