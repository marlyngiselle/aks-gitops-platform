# 0002. Tenancy through a kustomize namespace component

Status: Accepted

## Context

Teams share one cluster per environment. Each team needs a namespace with the same guardrails (quota, defaults, network isolation, RBAC, workload identity), and onboarding should be a pull request a team can open on its own. Options considered:

| Option | Why not |
| --- | --- |
| A Helm chart per tenant | Adds templating logic and a chart release process for what is static YAML with six values |
| Flux `postBuild.substitute` variables | Works in-cluster, but `kustomize build` renders `${VAR}` placeholders, so CI cannot validate the real output |
| A tenancy operator (Capsule, HNC) | Another controller to run and upgrade, and a CRD API teams must learn, for needs that plain Kubernetes objects already cover |

## Decision

A kustomize Component (`platform/components/team-namespace`) holds plain manifests. Each team overlay sets `namespace:` and provides a `team-config` ConfigMap annotated `config.kubernetes.io/local-config`, which kustomize `replacements` copy into labels, the RoleBinding subject, the service account annotation and the quota. The ConfigMap is dropped from the output.

## Consequences

- `kustomize build platform/teams/<team>` shows exactly what will be applied, offline, and CI validates it like any other manifest.
- Adding a field to the template means adding one replacement. If the number of per-team knobs grows past a dozen, a Helm chart or an operator becomes worth its cost; that is the trigger to revisit this decision.
- Tenant isolation does not rely on Flux multi-tenancy. It rests on namespace-scoped RBAC for the team's Entra group, default-deny NetworkPolicies, Pod Security Admission and Gatekeeper constraints scoped to `platform.example.com/tier: tenant`.
- The platform layer runs with `prune: false`, so removing a team from Git never deletes a namespace by accident.
