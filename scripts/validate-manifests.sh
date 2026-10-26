#!/usr/bin/env bash
# Render every kustomize overlay in the repository and validate the output.
#
#   1. `kustomize build` must succeed for every kustomization (components are
#      exercised through the overlays that use them).
#   2. Every Flux Kustomization under clusters/ must point at a path that
#      exists and builds.
#   3. When kubeconform is installed, rendered objects are validated against
#      the Kubernetes and CRD JSON schemas.
#
# Usage: scripts/validate-manifests.sh   (from any directory)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CRD_SCHEMAS="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

if command -v kubeconform >/dev/null 2>&1; then
  HAVE_KUBECONFORM=1
else
  HAVE_KUBECONFORM=0
  echo "WARN: kubeconform not found, skipping schema validation" >&2
fi

failures=0

echo "==> Building kustomizations"
while IFS= read -r dir; do
  # Kustomize components cannot be built on their own.
  if grep -q '^kind: Component' "$dir/kustomization.yaml"; then
    continue
  fi
  rendered="$OUT/$(echo "$dir" | tr '/' '_').yaml"
  if kustomize build "$dir" > "$rendered"; then
    echo "  ok    $dir"
  else
    echo "  FAIL  $dir"
    failures=$((failures + 1))
    continue
  fi
  if [ "$HAVE_KUBECONFORM" -eq 1 ]; then
    # Gatekeeper constraint kinds are generated at runtime from their
    # templates, so they have no published schema.
    if ! kubeconform -strict -summary -output text \
      -ignore-missing-schemas \
      -schema-location default \
      -schema-location "$CRD_SCHEMAS" \
      "$rendered"; then
      failures=$((failures + 1))
    fi
  fi
done < <(find . -name kustomization.yaml -not -path './.git/*' -exec dirname {} \; | sed 's#^\./##' | sort)

echo "==> Checking Flux Kustomization paths"
for cluster in clusters/*/; do
  while IFS= read -r path; do
    path="${path#./}"
    if [ -f "$path/kustomization.yaml" ]; then
      echo "  ok    ${cluster%/} -> $path"
    else
      echo "  FAIL  ${cluster%/} -> $path (no kustomization.yaml)"
      failures=$((failures + 1))
    fi
  done < <(kustomize build "$cluster" | awk '/^  path: /{print $2}')
done

if [ "$failures" -gt 0 ]; then
  echo "==> $failures check(s) failed" >&2
  exit 1
fi
echo "==> All manifest checks passed"
