#!/usr/bin/env python3
"""Fails when a suppression is missing from DEBT.md, or DEBT.md lists one that no longer exists.

A suppression is any `swiftlint:disable` comment or a `nonisolated(unsafe)` concurrency escape
(rule name `nonisolated_unsafe`). Each must have a DEBT.md table row `| path | rule | reason |`
with a non-empty reason.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUPPRESSION = re.compile(r"swiftlint:disable(?::next|:this|:previous)?\s+([\w\s]+)")
ROW = re.compile(r"^\|\s*`?([^|`]+?)`?\s*\|\s*`?([\w]+)`?\s*\|\s*([^|]*?)\s*\|\s*$")


def suppressions():
    found = set()
    for folder in ("Sources", "Tests", "Plugins"):
        for path in sorted((ROOT / folder).rglob("*.swift")):
            for line in path.read_text(encoding="utf-8").splitlines():
                if "nonisolated(unsafe)" in line and not line.lstrip().startswith("//"):
                    found.add((str(path.relative_to(ROOT)), "nonisolated_unsafe"))
                match = SUPPRESSION.search(line)
                if match:
                    for rule in match.group(1).split():
                        found.add((str(path.relative_to(ROOT)), rule))
    return found


def ledger():
    rows = {}
    for line in (ROOT / "DEBT.md").read_text(encoding="utf-8").splitlines():
        match = ROW.match(line)
        if match and match.group(1) not in ("File", "---") and not set(match.group(1)) <= set("-: "):
            rows[(match.group(1).strip(), match.group(2))] = match.group(3)
    return rows


def main():
    found, rows = suppressions(), ledger()
    errors = [f"{path}: suppression of `{rule}` is not in DEBT.md" for path, rule in sorted(found - rows.keys())]
    errors += [f"DEBT.md: `{rule}` in {path} has no reason" for (path, rule), reason in rows.items() if not reason]
    errors += [f"DEBT.md: `{rule}` in {path} is no longer suppressed; delete the row" for path, rule in sorted(rows.keys() - found)]
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    print(f"debt: {len(found)} suppression(s), {len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
