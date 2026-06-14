#!/usr/bin/env bash
# Stop and deregister the self-hosted runner.
set -euo pipefail
cd "$(dirname "$0")"
# RUNNER_TOKEN only matters at `up`; supply a placeholder so compose can
# interpolate the file while tearing down.
RUNNER_TOKEN=unused docker compose down
echo "Runner stopped and deregistered."
