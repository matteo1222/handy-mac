#!/usr/bin/env bash
# Proves the fence holds: a HandyCore file importing a banned framework must fail the build,
# and SwiftLint must reject clock, dispatch and CGEvent use in HandyCore.
set -euo pipefail
cd "$(dirname "$0")/.."

probe=Sources/HandyCore/_FenceProbe.swift
trap 'mv -f "$probe" "${TMPDIR:-/tmp}/_FenceProbe.swift.removed" 2>/dev/null || true' EXIT

for module in AppKit AVFoundation Vision; do
  printf 'import %s\n' "$module" > "$probe"
  if swift build --target HandyCore >/tmp/handy-fence.log 2>&1; then
    echo "FAIL: HandyCore built while importing $module" >&2
    exit 1
  fi
  grep -q "HandyCore must not import $module" /tmp/handy-fence.log || {
    echo "FAIL: build failed for another reason while importing $module" >&2
    cat /tmp/handy-fence.log >&2
    exit 1
  }
  echo "ok: import $module in HandyCore fails to compile"
done

cat > "$probe" <<'EOF'
import Foundation
func probe() {
    _ = Date()
    DispatchQueue.main.async {}
    Task { try? await Task.sleep(nanoseconds: 1) }
    _ = CGEvent.self
}
EOF
lint=$(swiftlint lint --quiet --reporter emoji "$probe" 2>/dev/null || true)
for rule in core_no_wall_clock core_no_dispatch core_no_task_sleep core_no_cgevent; do
  grep -q "$rule" <<<"$lint" || { echo "FAIL: SwiftLint missed $rule" >&2; echo "$lint" >&2; exit 1; }
  echo "ok: swiftlint rejects $rule"
done
