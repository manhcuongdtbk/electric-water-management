#!/usr/bin/env bash
# Guardrail (ADR-040): a pull request labelled `customer-facing` MUST add or
# modify a demo spec (spec/demo/**). Internal pull requests (no label) are exempt.
# Inputs via env: LABELS_JSON (pull_request.labels as JSON), BASE_SHA, HEAD_SHA.
# FAIL-LOUD: a labelled pull request without a demo spec change → exit 1.
set -uo pipefail

LABEL="customer-facing"

if ! printf '%s' "${LABELS_JSON:-[]}" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${LABEL}\""; then
  echo "✓ check-demo-spec: pull request not labelled '${LABEL}' — demo spec not required."
  exit 0
fi

changed="$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}" -- 'spec/demo/' || true)"
if [[ -n "$changed" ]]; then
  echo "✓ check-demo-spec: '${LABEL}' pull request touches spec/demo — OK."
  exit 0
fi

echo "✗ check-demo-spec: pull request is labelled '${LABEL}' but adds/modifies no spec/demo/** file."
echo "  Customer-facing changes must ship a demo spec (ADR-040). Add one under spec/demo/."
exit 1
