# Architecture decision records

Short records of the decisions that shape this platform: the context, the choice and what it costs. A superseded decision stays in place with its status updated, so the reasoning history is never lost.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](0001-flux-via-aks-extension.md) | Bootstrap Flux through the AKS cluster extension | Accepted |
| [0002](0002-namespace-as-a-service.md) | Tenancy through a kustomize namespace component | Accepted |
| [0003](0003-gatekeeper-via-flux.md) | Upstream Gatekeeper via Flux instead of the Azure Policy add-on | Accepted |
| [0004](0004-ingress-now-gateway-api-next.md) | ingress-nginx today, Gateway API as the next step | Accepted |
