#!/usr/bin/env python3
"""Human-readable summary of the generated IL2CPP layout (used by `make cpm-info`).

`Resources/cpm_il2cpp_layout.json` is a generated artifact produced by tools/cpm_il2cpp.py
from the game's IL2CPP dump, so this reader only reports what the dylib actually uses:
how many classes/fields/enums were resolved, and which classes came out empty (a strong
sign the dump is from a different game build than the layout spec).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Resources" / "cpm_il2cpp_layout.json"
SPEC = ROOT / "tools" / "cpm_layout_spec.json"


def expectations() -> dict:
    """{class id: [field names the spec insists on]} — `*`/`!x` entries are not names."""
    if not SPEC.exists():
        return {}
    try:
        classes = json.loads(SPEC.read_text(encoding="utf-8")).get("classes", [])
    except (ValueError, OSError):
        return {}
    out = {}
    for entry in classes:
        key = entry.get("id") or entry.get("name")
        wanted = [f for f in (entry.get("fields") or [])
                  if isinstance(f, str) and f not in {"*", "*static"} and not f.startswith("!")]
        if key and wanted:
            out[key] = wanted
    return out


def main() -> int:
    if not PATH.exists():
        print("  (no generated layout — run: make layout DUMP=dump.cs)")
        return 0

    data = json.loads(PATH.read_text(encoding="utf-8"))
    classes = data.get("classes") or {}
    enums = data.get("enums") or {}
    dump = data.get("dump") or {}

    instance_fields = sum(len(c.get("fields") or {}) for c in classes.values())
    static_fields = sum(len(c.get("staticFields") or {}) for c in classes.values())
    methods = sum(len(c.get("methods") or {}) for c in classes.values())

    sha = str(dump.get("sha256") or "")[:12] or "?"
    print(f"  {len(classes)} classes / {instance_fields + static_fields} fields "
          f"({static_fields} static) / {methods} methods / {len(enums)} enums")
    print(f"  dump: {dump.get('path', 'dump.cs')} ({dump.get('bytes', 0) / 1e6:.1f} MB, sha256 {sha}…)")

    want = expectations()
    problems = []
    for name, info in sorted(classes.items()):
        got = set(info.get("fields") or {}) | set(info.get("staticFields") or {})
        missing = [f for f in want.get(name, []) if f not in got]
        if missing:
            problems.append(f"{name}: {', '.join(missing)}")
    if problems:
        for line in problems:
            print(f"  warning: layout is missing {line}")
    else:
        print("  every field the layout spec asks for is present (base classes carry their own)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
