#!/usr/bin/env bash
# Builds and starts a verification instance of Handy on its own control socket, then waits until
# it answers. Prints the environment to export. Stop it with scripts/verify/cleanup.sh.
#   eval "$(scripts/verify/launch.sh)"
set -euo pipefail
cd "$(dirname "$0")/../.."
STATE=.build/verify
mkdir -p "$STATE" "$STATE/evidence"
SOCKET=${HANDY_CONTROL_SOCKET:-/tmp/handy-verify-$$.sock}
scripts/package-app.sh debug >/dev/null
swift build -q --product handyctl
if [[ -f "$STATE/handy.pid" ]] && kill -0 "$(cat "$STATE/handy.pid")" 2>/dev/null; then
  echo "error: a verification instance is already running (pid $(cat "$STATE/handy.pid")); run scripts/verify/cleanup.sh" >&2
  exit 1
fi
HANDY_CONTROL_SOCKET="$SOCKET" .build/app/Handy.app/Contents/MacOS/Handy >"$STATE/handy.log" 2>&1 &
echo $! > "$STATE/handy.pid"
echo "$SOCKET" > "$STATE/socket"
for _ in $(seq 1 50); do
  if HANDY_CONTROL_SOCKET="$SOCKET" .build/debug/handyctl state >/dev/null 2>&1; then
    echo "export HANDY_CONTROL_SOCKET=$SOCKET"
    exit 0
  fi
  sleep 0.2
done
echo "error: Handy did not answer on $SOCKET; see $STATE/handy.log" >&2
exit 1
