#!/usr/bin/env bash
# Start (or restart) the self-hosted runner with a fresh registration token.
# Registration tokens expire after ~1 hour, so we mint a new one each start.
set -euo pipefail
cd "$(dirname "$0")"

REPO="manhcuongdtbk/electric-water-management"

echo "Minting a fresh runner registration token via gh..."
RUNNER_TOKEN="$(gh api -X POST "repos/${REPO}/actions/runners/registration-token" -q '.token')"
export RUNNER_TOKEN

echo "Starting the runner container (privileged, with its own Docker daemon)..."
docker compose up -d --force-recreate

echo
echo "Runner is starting. Useful commands:"
echo "  Status : gh api repos/${REPO}/actions/runners -q '.runners[] | \"\\(.name) \\(.status)\"'"
echo "  Logs   : docker logs -f ewm-gh-runner"
echo "  Stop   : ./stop.sh"
