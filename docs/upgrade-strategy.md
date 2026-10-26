# Upgrade strategy

Three things move at different speeds and are upgraded through different paths.

| What | Path | Cadence | Who approves |
| --- | --- | --- | --- |
| Kubernetes patch versions, node images | AKS auto-upgrade (`patch` channel, `NodeImage` OS channel) inside the weekly maintenance window | Automatic | Nobody, by design |
| Kubernetes minor version | `kubernetes_version` in `infra/terraform/environments/<env>.tfvars` | About three times a year, dev first | Platform team, pull request |
| Add-on charts (ingress, cert-manager, Prometheus, Gatekeeper, external-dns) | Chart `version` in `infrastructure/controllers/base` | Monthly review, or on a security advisory | Platform team, pull request |
| Flux itself | AKS Flux extension, updated by AKS | Automatic, minor versions follow AKS | Nobody; pin `version` on the extension if a release must be held |

## Kubernetes minor version

1. Read the upstream and AKS release notes for removed APIs. Check the cluster for deprecated API usage (Azure portal, "Diagnose and solve problems", or a tool such as `kubent`).
2. Bump `kubernetes_version` in `dev.tfvars`, plan and apply. Node pools surge by the configured `max_surge` and drain node by node, so PodDisruptionBudgets are respected.
3. Let dev run for at least a week. Watch `kubectl get kustomizations -A` and `kubectl get helmreleases -A` for anything not Ready.
4. Repeat for `prod.tfvars`.

AKS supports a minor version for about twelve months. Staying at most one minor version behind the newest GA release leaves room for a skipped cycle without falling out of support.

`kubernetes_version` holds a minor version only (`1.34`). AKS treats it as an alias and the `patch` channel moves the patch version underneath it, so patch upgrades never appear as Terraform drift. The same variable sets `orchestrator_version` on every node pool, so one change upgrades the control plane first and the pools after it.

## Add-on charts

All charts are pinned to an exact version. A floating range would let an upstream release change prod without a review.

1. Bump the version in `infrastructure/controllers/base/<addon>.yaml`. For a risky upgrade (major version, CRD changes), put the new version in the dev overlay only.
2. Read the chart's upgrade notes. kube-prometheus-stack and Gatekeeper ship CRD changes, and their HelmReleases use `crds: CreateReplace` so Flux applies them. cert-manager manages its CRDs through its own chart values (`crds.enabled`, with `crds.keep` so an uninstall never deletes certificates).
3. Merge, check the HelmRelease is Ready in dev, then promote.
4. A failed upgrade is rolled back by helm-controller (`remediation.retries: 3`, `remediateLastFailure: true`).

A dependency bot (Renovate or Dependabot) can open these pull requests automatically; both understand Flux HelmRelease versions.

## Gatekeeper policies

Policy changes are upgrades too, and the most likely to break a team.

1. Add or change the constraint in `policies/constraints/base`. Dev runs it as `dryrun` automatically.
2. In the same pull request, override it to `dryrun` in the prod overlay.
3. Watch the audit results in both environments: `kubectl get <kind> <name> -o yaml` lists current violations.
4. When prod shows no violations, or the owning teams have fixed them, remove the prod override in a follow-up pull request.

The base Gatekeeper webhook fails open (`Ignore`), and the prod overlay fails closed (`Fail`). With `Fail`, a broken Gatekeeper blocks deployments, so Gatekeeper upgrades in prod go after a successful dev upgrade and with three replicas.

## Ingress controller

The upstream ingress-nginx project stopped publishing releases in March 2026 (the last chart release in its Helm repository is from 2026-03-19). It is pinned here and still works, but it is on a migration path to the Gateway API, described in [ADR 0004](adr/0004-ingress-now-gateway-api-next.md).
