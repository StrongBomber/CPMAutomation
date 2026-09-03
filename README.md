# OverlayTweak v2.1.0 — CPM Image-to-Vinyl Automation

iOS-only floating overlay tweak for **Car Parking Multiplayer (CPM)** that turns any picture
into vinyl layers inside the game's own vinyl editor. It is *non-destructive*: the game binary
is never patched, no memory is written, and the only thing the tweak sends to the game is a
touch — after you approve a plan.

> **Android is gone.** The old `build-android.yml` workflow built an `android/` project that
> never existed in this repo. The tweak is injected into the iOS app bundle, and every
> generated artifact (game layout, UI anchors) is iOS/landscape-only.

---

## 1. What it does

```
 reference image                    CPM vinyl editor
       │                                   ▲
       ▼                                   │ touches
 ┌──────────────┐   shapes   ┌──────────────┴─────────────┐
 │ Shape        │ ─────────► │ Execution controller       │
 │ decomposer   │            │ (step machine, dry-run)    │
 └──────────────┘            └──────────────┬─────────────┘
       ▲                                    │ screen points
       │ ROI in image space                 ▼
 ┌─────┴────────────┐            ┌──────────────────────────┐
 │ ROI overlay      │            │ Touch injector           │
 │ (drag a box)     │            │ synthetic UIEvent → game │
 └──────────────────┘            └──────────────────────────┘
       ▲
       │  canvas rect (points)
 ┌─────┴────────────────┐        ┌──────────────────────────────┐
 │ UI calibration       │◄──────►│ il2cpp bridge (read-only)    │
 │ anchors + screen map │        │ dump.cs offsets, layer count │
 └──────────────────────┘        └──────────────────────────────┘
```

* **Shape decomposer** (`Core/CPMShapeDecomposer.m`) — quantises the ROI to a small palette,
  runs 8-connected component labelling per colour, classifies each blob
  (square / circle / triangle / line / polygon), and caps the result at the game's layer budget.
* **Vinyl model** (`Core/CPMVinylShape.m`) — one layer = position, scale, rotation, per-channel
  RGBA, z-order. Converts to the dictionary form the game's `VinylData` uses.
* **Execution controller** (`Core/CPMExecutionController.m`) — `Idle → LoadingImage →
  DecomposingImage → Calibrating → PlacingLayers → Verifying → Finished`, with pause, stop,
  emergency stop, progress, and per-step logging.
* **Touch injector** (`Core/CPMTouchInjector.m`) — delivers taps/drags/slider drags. Default
  backend builds `UITouch`/`UIEvent` stand-ins and calls `touchesBegan/Moved/Ended:` on the
  game's own input view (no entitlements needed); IOHID is opt-in; if neither works the
  injector reports *visual only* instead of pretending to succeed.
* **UI calibration** (`Core/CPMUICalibration.m`) — maps the reference screenshot space to the
  current screen, holds the editor-button anchors, and persists itself to `NSUserDefaults`.
* **il2cpp bridge** (`Core/CPMIl2CppBridge.m`) — read-only look-up of the game's own class
  layout, resolved from `dump.cs` at build time.

## 2. The game structure comes from `dump.cs`

`dump.cs` (the Il2CppDumper output committed in this repo) is the only authority about the
game's internals. Nothing about `VinylsEditor`, `VinylData`, `StickerItem`, `JoystickNGUI`,
`MoveSliderToTarget` etc. is guessed.

```
dump.cs ──► tools/cpm_il2cpp.py ──► Resources/cpm_il2cpp_layout.json
   spec: tools/cpm_layout_spec.json          │
                                             ▼
                                  Core/CPMGameLayout.{h,m}   (committed)
```

* `make layout DUMP=dump.cs` regenerates the layout; `make layout-check` verifies the
  committed header still matches the dump (class, field offsets, enum values, dump sha256).
* Static fields are recorded as `offset 0x0` + `isStatic`, and the runtime never dereferences
  that offset — it calls the `il2cpp_*` static accessors, because Il2CppDumper's static offsets
  are image-relative, not instance offsets.
* At runtime the bridge re-reads the same offsets through `il2cpp` and compares them with the
  compiled-in values. A mismatch increments `layoutDriftCount` and marks the readout
  `layoutStale`, so the panel says *"game updated — layout drifted"* instead of tapping at
  wrong coordinates. If the game was stripped of `il2cpp` exports, the bridge reports why and
  every consumer degrades to blind touch mode; it never invokes game code and never crashes.

The same idea covers the editor UI geometry: `Resources/cpm_ui_anchors.json` (13 anchors on a
844 × 390 landscape reference) is compiled into `Core/CPMAnchorsDefault.h` by
`make anchors`. The dylib is injected into the game's bundle, so JSON is **not** read at
runtime — editing the JSON without running `make anchors` changes nothing.

## 3. Building

### On macOS (needs Xcode)

```bash
xcode-select -s /Applications/Xcode.app   # or a full Xcode_16.x.app
make            # → Overlay.dylib (arm64, +arm64e when the arch compiles)
make check      # anchors + layout + repo checks + static parse of every source
make cpm-info   # what the generated headers actually contain
```

`Overlay.dylib` is installed next to the game's binary (`TrollStore`, Sideloadly, or a
jailbreak `.dylib` loader). `make inject IPA_PATH=... ` re-packs an IPA when `tools/insert_dylib`
is available.

### Without Xcode (Linux CI box, review, quick edit)

```bash
python3 -m pip install libclang          # or: brew install llvm
make check
```

`tools/cpm_check.py` parses every `.m` in the dylib against a stub iOS SDK
(`tools/sdkstub/`) with libclang — it catches typos, missing selectors, wrong property
attributes and ARC/nullability mistakes, which is exactly what breaks a tweak between two
macOS builds. It is a **lint gate, not a linker**: `make` on macOS stays the authoritative
build. Run the whole set with `make check`; run one file with
`python3 tools/cpm_check.py OverlayManager.m`.

### CI

`ci/build.yml` is the canonical workflow; `.github/workflows/build.yml` is a byte-for-byte
mirror (GitHub only reads that path). It runs on `macos-15`, checks out with
`actions/checkout@v4`, runs `make check`, `make clean`, `make`, and uploads `Overlay.dylib`
with `actions/upload-artifact@v4`.

Nothing under `.github/workflows/` can be pushed with this repo's automation token (GitHub
refuses workflow paths without the `workflows` permission), so that directory is maintained by
copying: `ci/build.yml` is the file to edit, and `.github/workflows/build.yml` must be pasted
over it in the web UI. This is also how the obsolete `build-android.yml` gets deleted — it is
removed in the working tree here, and needs the same one-line removal on GitHub.

## 4. Using it in game

The panel is Turkish, like the rest of the tweak; its diagnostics/log rows stay English on
purpose, because they quote internal names (class, offset, backend).

1. Open the vinyl editor in CPM — the panel assumes the editor's landscape layout.
2. Tap the overlay menu (⚙ kenar sekmesi) → **Otomatik çizim** in the quick-button hub.
3. **Görsel yükle** — the shared PHPicker opens; the chosen photo also becomes the overlay
   image, so crop / warp / perspective tools can be applied before drawing. **Temizle** drops it.
4. **Boya alanını seç (ROI)** — drag the box over the part of the *car* the artwork should
   cover, then **Bölgeyi onayla**. That rectangle becomes the calibration canvas rect and is
   stored with the anchors.
5. **Planı önizle** runs the decomposition only: the log reports how many layers were planned,
   which were dropped for the budget, and the overlay shows the plan — no touches.
6. **Katman sınırı** (the label prints the game's own cap next to your limit, e.g.
   `Katman sınırı: 42 (oyun: 6 / 50 kullanımda)`) and **Yerleşme gecikmesi** (how long the run
   waits for the UI to settle; 15 ms is the floor, not a good default).
7. **Sadece önizleme (dokunuş yok)** is ON for a first run: the plan is computed and the finger
   positions are drawn, but nothing is injected. Switch it off when the preview matches the car.
   **Bitince Onay'a bas** makes the run tap the editor's Confirm button at the end.
8. **BAŞLAT** → progress bar + `Katman: n / m`. **Duraklat / Devam / Durdur** work during the
   run; **ACİL DURDUR** (also a long-press on the overlay) drains the queue immediately.

Hiding the panel does not stop a running session: the controller is owned by
`OverlayManager`, so the run keeps going (and keeps logging) while you look at the car.

## 5. Persistence keys

| Key | Owner | Meaning |
|-----|-------|---------|
| `cpm_preview_only` | panel | dry-run switch (unset ⇒ ON, first run never touches the game) |
| `cpm_layer_limit` | panel | max layers per vinyl |
| `cpm_touch_delay_ms` | panel | settle delay between touches |
| `cpm_autosave_vinyl` | panel | tap the editor's Confirm button at the end |
| `cpm_ui_anchors` / `cpm_calibration_version` | calibration | anchors, reference space, canvas rect |
| `cpm_roi_rect` | manager | last confirmed ROI |
| `cpm_autodraw_active` / `cpm_autodraw_paused` | manager | run state across panel open/close |
| `cpm_last_session_shapes` | controller | last decomposition (debug) |
| `cpm_emergency_stop` | injector | latched stop flag |
| `cpm_use_iohid_backend` | injector | opt into the IOHID backend (needs entitlements) |

## 6. Safety model

* **Read-only** game introspection: the bridge only calls `il2cpp_class_from_name`,
  `il2cpp_field_get_offset` and friends. No `il2cpp_runtime_invoke`, no hooks, no writes.
* **Touches are the only write path** into the game, and they are gated behind the preview
  switch plus an explicit Start tap.
* **No binary patching**: nothing in this repo edits the IPA's Mach-O other than the standard
  `install_name` insertion performed by `make inject` on *your* copy.
* **Layer budget**: the controller stops at `min(user limit, game cap − safety margin)` and
  refuses to start when calibration is missing and `requiresVerifiedCalibration` is on.
* Everything runs on a serial queue; the UI is only touched from the main thread.

## 7. Layout

```
OverlayEntry.m              constructor + OVERLAY_TARGET_BUNDLE_ID guard + delayed setup
OverlayManager.{h,m}        overlay window, quick hub, CPM wiring (panel + controller)
OverlayView.{h,m}           image view: crop / warp / perspective / colour pick
SettingsViewController.{h,m} card settings, shared PHPicker path
OverlayCommon.h             version, defaults keys, logging, helpers

Core/CPMVinylShape          one vinyl layer
Core/CPMShapeDecomposer     image → layers
Core/CPMExecutionController step machine, dry-run, progress, logs
Core/CPMTouchInjector       touch delivery (synthetic UIEvent / IOHID / visual-only)
Core/CPMUICalibration       anchors + screen↔canvas mapping + persistence
Core/CPMIl2CppBridge        read-only game introspection + drift detection
Core/CPMGameLayout          generated offsets table (from dump.cs)
Core/CPMAnchorsDefault.h    generated anchor table (from Resources/cpm_ui_anchors.json)

UI/CPMAutoDrawViewController  the panel
UI/CPMROIOverlayView          ROI selector

Resources/cpm_il2cpp_layout.json  generated, kept for auditability
Resources/cpm_ui_anchors.json     editable anchor source
tools/cpm_il2cpp.py               dump.cs → layout (generate | check | show | selftest)
tools/cpm_anchors.py              JSON → anchor header (generate | check)
tools/cpm_check.py                libclang static check over the stub SDK
tools/cpm_show_layout.py          summary for `make cpm-info`
scripts/check_objc.py             repo-hygiene rules the CI enforces
```

## 8. Known limits

* **Backend reach.** Synthetic `UIEvent` delivery works in-process on any injected build, but a
  game that polls raw HID instead of `Input.touches` would need the IOHID path (entitlements).
  The panel prints which backend it got — believe that line, not the progress bar.
* **Layer budget.** CPM's editor caps how many vinyls one car holds; the generator reads that
  cap when the bridge resolves, otherwise the user limit applies. Shapes above the cap are
  dropped and reported (`droppedShapeCount`), not silently skipped.
* **Fine art.** Photographic input degrades: the game offers flat primitives, so the
  decomposition prefers large regions and a small palette. Detailed logos are better drawn with
  `configForDetailedLogoWithMaxLayers:` and accepted as an approximation.
* **Calibration is device/orientation specific.** The anchors are measured in CPM's landscape
  vinyl editor (`844 × 390 pt`). At runtime the profile is re-aimed at the *game window*, not at
  `UIScreen.mainScreen.bounds` — which never rotates on iPhone and used to make every tap land on
  the wrong axis. If the window's orientation differs from the table, the table is re-derived
  rotated 90° (verified round-trip), the derived canvas follows it, and the paint area must be
  confirmed again. Edited coordinates still belong in `Resources/cpm_ui_anchors.json` + `make anchors`.

## 9. Troubleshooting

| Symptom | Check |
|---------|-------|
| overlay never appears | Console for `[OverlayTweak]` / `[CPM-Automation]` logs; is the dylib load command present (`LC_LOAD_DYLIB`)? If the build sets `OVERLAY_TARGET_BUNDLE_ID`, does it match the game's bundle id? (default: no restriction) |
| **BAŞLAT does nothing** | the status line now says why (`Başlatılamadı: …`). Usual causes: no image; calibration not usable for this screen (the panel re-derives it from the window — reopen the panel after rotating); a preview is still running (use the cached plan by waiting, or the button is disabled during preview); the game reports no free layers. |
| ran, progress bar moved, nothing in game | **Önizleme** (preview only) is ON — the button turns grey and reads `ÖNİZLE`, and a toast says `Önizleme sürüyor`. Also check the `Dokunma:` line: `visual only` means nothing can be delivered. |
| panel opens but Start is greyed out | a run is already in progress (or the preview is computing) |
| "no touches will be sent" in the log | Preview only is ON — that is the default |
| log says *visual only* backend | the injector could not find an input view; taps will be shown, not sent |
| log says layout drift | game updated → re-dump and `make layout DUMP=dump.cs`, then rebuild |
| touches land on wrong buttons | re-confirm the ROI, or recalibrate `Resources/cpm_ui_anchors.json` + `make anchors` |
| layer count stops early | `maxLayers` (panel) or the game's own cap; see `Layers: x / y` |
| stutter | raise Settle delay (the editor animates; 15 ms is the floor, not a good default) |
| `make check` prints `SKIP cpm_check` | install libclang bindings: `python3 -m pip install libclang` |

## 10. Credits

Base overlay tweak by **StrongBomber**; the CPM automation extension, the `dump.cs`-driven
layout pipeline and the static check harness were built with **Arena.ai Agent Mode**. Touch
injection ideas follow public jailbreak-community write-ups of `IOHIDEventSystemClient`.
Both parts are MIT-licensed.
