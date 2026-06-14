#!/usr/bin/env bash
# Guardrail (ADR-040 + ADR-052): a pull request labelled `customer-facing` MUST
# add or modify a demo spec (spec/demo/**) — FAIL-LOUD if it does not. A pull
# request WITHOUT the label is exempt from blocking, but ADR-052 Lớp C adds a
# non-blocking ADVISORY: if such a pull request touches customer-visible paths
# (app/views/**, app/javascript/controllers/**) yet ships no demo spec, print a
# loud reminder (exit 0) so a forgotten label still surfaces — without
# false-positive blocking of internal view tweaks / admin-only screens.
# Inputs via env: LABELS_JSON (pull_request.labels as JSON), BASE_SHA, HEAD_SHA.
set -uo pipefail

LABEL="customer-facing"

demo_changed="$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}" -- 'spec/demo/' || true)"

if ! printf '%s' "${LABELS_JSON:-[]}" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"${LABEL}\""; then
  # Unlabelled. Blocking is off; run the ADR-052 Lớp C path-inference advisory.
  if [[ -z "$demo_changed" ]]; then
    customer_paths="$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}" \
      -- 'app/views/' 'app/javascript/controllers/' || true)"
    if [[ -n "$customer_paths" ]]; then
      echo "⚠ check-demo-spec (advisory, ADR-052): pull request is NOT labelled '${LABEL}'"
      echo "  but touches customer-visible paths and ships no demo spec:"
      printf '%s\n' "$customer_paths" | sed 's/^/    /'
      echo "  If this change is customer-facing, add the '${LABEL}' label and a demo"
      echo "  spec under spec/demo/ (rails g demo:spec <feature>). Advisory only — not blocking."
      exit 0
    fi
  fi
  echo "✓ check-demo-spec: pull request not labelled '${LABEL}' — demo spec not required."
  exit 0
fi

if [[ -n "$demo_changed" ]]; then
  echo "✓ check-demo-spec: '${LABEL}' pull request touches spec/demo — OK."
  exit 0
fi

echo "✗ check-demo-spec: pull request is labelled '${LABEL}' but adds/modifies no spec/demo/** file."
echo "  Customer-facing changes must ship a demo spec (ADR-040). Add one under spec/demo/."
exit 1
