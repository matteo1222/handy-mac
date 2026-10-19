#!/usr/bin/env bash
pkill -x Handy 2>/dev/null || true
for _ in $(seq 1 25); do pgrep -x Handy >/dev/null || exit 0; sleep 0.2; done
