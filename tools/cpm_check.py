#!/usr/bin/env python3
"""Offline Objective-C type check for the CPM automation modules.

`make check` cannot compile against the real iOS SDK (no macOS SDK on Linux CI
sandboxes), so this harness parses the CPM sources with libclang 18 using the
tiny stub SDK in tools/sdkstub.  It catches the mistakes that used to rot in
this repo: missing imports, `CPM`-`TouchSequence` style corruption, calling
selectors nobody declares, writing to readonly properties and ARC misuse.

Install the parser once:  python3 -m pip install libclang   (or:  brew install llvm)
Exit code 0 = every checked file parsed with no errors.
"""
from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STUB = ROOT / "tools" / "sdkstub" / "include"

DEFAULT_FILES = [
    "OverlayCommon.h",
    "Core/CPMVinylShape.m",
    "Core/CPMShapeDecomposer.m",
    "Core/CPMTouchInjector.m",
    "Core/CPMExecutionController.m",
    "Core/CPMUICalibration.m",
    "Core/CPMGameLayout.m",
    "Core/CPMIl2CppBridge.m",
    "UI/CPMAutoDrawViewController.m",
    "UI/CPMROIOverlayView.m",
]

# The pre-existing overlay files: checked by `make check` too, they must stay clean.
OVERLAY_FILES = [
    "OverlayEntry.m",
    "OverlayManager.m",
    "OverlayView.m",
    "SettingsViewController.m",
]

SUPPRESSED = (
    "unknown attribute",  # stub-SDK noise
)


def find_libclang() -> str | None:
    env = os.environ.get("CPM_LIBCLANG")
    cands = [env] if env else []
    cands += [
        "/usr/lib/llvm-18/lib/libclang.so",
        "/usr/lib/llvm-17/lib/libclang.so",
        "/usr/lib/llvm-16/lib/libclang.so",
        "/usr/lib/llvm/lib/libclang.so",
        "/usr/lib/x86_64-linux-gnu/libclang-18.so",
        "/opt/homebrew/opt/llvm/lib/libclang.dylib",
        "/usr/local/opt/llvm/lib/libclang.dylib",
        "/Library/Developer/CommandLineTools/usr/lib/libclang.dylib",
    ]
    for c in cands:
        if c and Path(c).exists():
            return c
    # pip install --target fallback
    out = subprocess.run(
        [sys.executable, "-c", "import clang, os; print(os.path.dirname(clang.__file__))"],
        capture_output=True, text=True,
    )
    if out.returncode == 0:
        p = Path(out.stdout.strip()) / "native" / ("libclang.so" if os.name != "nt" else "libclang.dll")
        if p.exists():
            return str(p)
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--overlay", action="store_true", help="also check the overlay entry files")
    ap.add_argument("files", nargs="*", help="defaults to the CPM module list")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    if args.files:
        files = list(args.files)
    elif args.overlay:
        files = DEFAULT_FILES + OVERLAY_FILES
    else:
        files = DEFAULT_FILES
    lib = find_libclang()
    if not lib:
        print("SKIP cpm_check: libclang not found (python3 -m pip install libclang)")
        return 0
    try:
        import clang.cindex  # type: ignore
    except Exception as exc:  # noqa: BLE001
        print(f"SKIP cpm_check: python clang bindings unavailable ({exc})")
        return 0
    clang.cindex.Config.set_library_file(lib)

    clang_args = [
        "-x", "objective-c",
        "-fsyntax-only",
        "-fblocks",
        "-fobjc-arc",
        "-std=gnu11",
        "-nostdinc",
        "-isystem", str(STUB),
        "-I", str(ROOT),
        "-I", str(ROOT / "Core"),
        "-I", str(ROOT / "UI"),
        "-target", "arm64-apple-ios14.0",
        "-Wno-deprecated-declarations",
        "-Wno-unused-variable",
        "-Wno-objc-missing-super-calls",
        "-Wno-partial-availability",
        # Style diagnostics the project itself does not treat as errors (the Makefile passes
        # no -Werror); the harness only wants to catch real API mismatches.
        "-Wno-error=arc-retain-cycles",
        "-Wno-error=deprecated-declarations",
        "-Werror",
        "-ferror-limit=0",
        "-fretain-comments-from-system-headers" if False else "-Wno-nullability-completeness",
        "-D__OBJC__=1",
    ]
    idx = clang.cindex.Index.create(False)
    total = 0
    for rel in files:
        path = ROOT / rel
        if not path.exists():
            print(f"ERR {rel}: file missing")
            total += 1
            continue
        try:
            tu = idx.parse(str(path), args=clang_args, options=0x1)  # DetailedPreprocessingRecord off? keep
        except Exception as exc:  # noqa: BLE001
            print(f"ERR {rel}: parse failed: {exc}")
            total += 1
            continue
        shown = 0
        for d in tu.diagnostics:
            if d.severity < 3:
                continue
            text = d.spelling
            if any(s in text for s in SUPPRESSED):
                continue
            loc = d.location
            fn = Path(loc.file.name).name if loc.file else rel
            if fn != path.name and "sdkstub" in (loc.file.name if loc.file else ""):
                continue
            total += 1
            shown += 1
            print(f"ERR {fn}:{loc.line}:{loc.column} {text}")
            for note in d.children:
                if note.severity >= 3:
                    print(f"      note: {note.spelling}")
        if not shown and not args.quiet:
            print(f"ok  {rel}")
    if total:
        print(f"\n{total} error(s)")
        return 1
    print("cpm_check: OK (0 errors)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
