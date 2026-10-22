#!/bin/sh
# Render every Helm chart of the repo (root/ and apps/*) and validate the
# resulting manifests with kubeconform. Runs in CI and locally:
#
#   ./ci/validate.sh                 # all charts
#   ./ci/validate.sh apps/immich     # only some charts
#
# Charts are copied to a temp dir before `helm dependency update`, so local
# runs never touch the Chart.lock files of the working tree.
set -eu

KUBECONFORM_VERSION="${KUBECONFORM_VERSION:-v0.8.0}"
# CRD schemas, in order: the CRDs bundled with the chart itself (exact
# version), then a community catalog (Argo CD, cert-manager, Traefik...).
# CRDs found in neither (e.g. ricoberger VaultSecret) are reported as skipped.
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/charts" "$WORK/rendered"

if ! command -v kubeconform >/dev/null 2>&1; then
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
  url="https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-${os}-${arch}.tar.gz"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$url"; else wget -qO- "$url"; fi \
    | tar -xz -C "$WORK/bin" kubeconform
  PATH="$WORK/bin:$PATH"
fi

# crd2schema.py needs PyYAML (CI installs py3-yaml; locally, use a venv if missing).
PY=python3
if ! python3 -c 'import yaml' 2>/dev/null; then
  python3 -m venv "$WORK/venv" && "$WORK/venv/bin/pip" install -q pyyaml
  PY="$WORK/venv/bin/python3"
fi
CI_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$#" -gt 0 ]; then
  charts="$*"
else
  charts="root $(ls -d apps/*/)"
fi

failed=""
for chart in $charts; do
  chart="${chart%/}"
  name="$(basename "$chart")"
  [ -f "$chart/Chart.yaml" ] || continue
  if [ ! -s "$chart/Chart.yaml" ]; then
    echo "==> $chart: empty Chart.yaml, skipped"
    continue
  fi
  echo "==> $chart"

  cp -R "$chart" "$WORK/charts/$name"
  if grep -q '^  - name:' "$chart/Chart.yaml"; then
    if ! helm dependency update "$WORK/charts/$name" >"$WORK/$name.deps.log" 2>&1; then
      cat "$WORK/$name.deps.log"
      failed="$failed $chart(deps)"
      continue
    fi
  fi

  # --include-crds: Argo CD applies them too, and they feed crd2schema.py.
  if ! helm template "$name" "$WORK/charts/$name" --namespace "$name" --include-crds >"$WORK/rendered/$name.yaml"; then
    failed="$failed $chart(template)"
    continue
  fi
  "$PY" "$CI_DIR/crd2schema.py" "$WORK/rendered/$name.yaml" "$WORK/schemas/$name"

  if ! kubeconform -strict -summary -ignore-missing-schemas \
      -schema-location default \
      -schema-location "$WORK/schemas/$name/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" \
      -schema-location "$CRD_SCHEMAS" \
      "$WORK/rendered/$name.yaml"; then
    failed="$failed $chart(schema)"
  fi
done

if [ -n "$failed" ]; then
  echo
  echo "FAILED:$failed"
  exit 1
fi
echo
echo "All charts rendered and validated."
