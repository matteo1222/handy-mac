#!/usr/bin/env bash
# Packages the app and (re)launches it, then waits for its control socket. Usage: scripts/run-app.sh [--no-build]
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" != "--no-build" ]]; then
  scripts/package-app.sh debug >/dev/null
  swift build -q --product handyctl
fi
scripts/stop-app.sh
open .build/app/Handy.app
for _ in $(seq 1 50); do
  .build/debug/handyctl state >/dev/null 2>&1 && exit 0
  sleep 0.2
done
echo "Handy did not answer on its control socket" >&2
exit 1
