# 0003. Upstream Gatekeeper via Flux instead of the Azure Policy add-on

Status: Accepted

## Context

AKS offers the Azure Policy add-on, which installs a managed Gatekeeper and syncs built-in or custom policy definitions from Azure Policy. The alternative is to install upstream Gatekeeper with Helm and keep ConstraintTemplates and Constraints in Git.

## Decision

Disable the Azure Policy add-on (`azure_policy_enabled = false`) and install upstream Gatekeeper through Flux. Templates and constraints live in `policies/`.

## Consequences

- Policies are reviewed, versioned and promoted like any other change, with the same pull request flow. The enforcement mode is an overlay patch: `dryrun` in dev, `deny` in prod.
- Policies are portable. The same `policies/` folder works on EKS or any conformant cluster, which matters for an organisation running more than one cloud.
- Custom Rego is in-house code. Each template is small and documented, and the community gatekeeper-library is the reference when adding new ones.
- The organisation loses the compliance dashboard that Azure Policy provides out of the box. Gatekeeper audit results are scraped by Prometheus (`infrastructure/configs/gatekeeper-podmonitor.yaml`) and can be alerted on instead.
- Running both would install two Gatekeepers with competing webhooks, so the add-on must stay disabled.
