#!/usr/bin/env bash
# Stops only the verification instance scripts/verify/launch.sh started. Evidence in
# .build/verify/evidence is kept.
set -euo pipefail
cd "$(dirname "$0")/../.."
STATE=.build/verify
if [[ -f "$STATE/handy.pid" ]]; then
  PID=$(cat "$STATE/handy.pid")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    for _ in $(seq 1 25); do kill -0 "$PID" 2>/dev/null || break; sleep 0.2; done
  fi
  mv "$STATE/handy.pid" "$STATE/handy.pid.stopped"
fi
if [[ -f "$STATE/socket" ]]; then
  SOCKET=$(cat "$STATE/socket")
  [[ -S "$SOCKET" ]] && mv "$SOCKET" "$STATE/last.sock.stale"
  mv "$STATE/socket" "$STATE/socket.stopped"
fi
echo "stopped; evidence kept in $STATE/evidence"
