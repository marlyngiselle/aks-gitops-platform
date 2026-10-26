# 0004. ingress-nginx today, Gateway API as the next step

Status: Accepted

## Context

Tenant applications need HTTP ingress with TLS from cert-manager. ingress-nginx is the controller most teams already know, and every chart in this repository, including the podinfo sample, supports the Ingress API. Upstream ingress-nginx stopped publishing releases in March 2026; the last chart release in its Helm repository is dated 2026-03-19.

## Decision

Ship ingress-nginx, pinned to its last release, with snippet annotations disabled. Plan the move to a Gateway API implementation as a separate piece of work, before the first unpatched vulnerability or Kubernetes version incompatibility forces it.

## Consequences

- The platform works today with the API that applications already use.
- An unmaintained edge component is a security risk that grows over time. The migration is tracked as platform work, not left open-ended.
- The migration path is incremental: install a Gateway API controller next to ingress-nginx, move applications one by one from Ingress to HTTPRoute (podinfo's chart already supports `httpRoute`), point DNS at the new load balancer, then remove ingress-nginx. The tenant NetworkPolicy `allow-ingress-nginx` gets a sibling for the new controller's namespace during the overlap.
- cert-manager supports Gateway API listeners, so certificate handling does not change shape.
