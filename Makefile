# ==============================================================================
# OverlayTweak - Makefile (Extended for CPM Image-to-Vinyl Automation)
# ==============================================================================
# Builds Overlay.dylib for device (iphoneos).
# Requires macOS + Xcode. arm64 is required; arm64e is best-effort.
# Supports CPM vinyl automation: shape decomposition, touch injection,
# UI calibration, and execution control.
# ==============================================================================

TARGET_NAME = Overlay.dylib
MIN_IOS     = 14.0

SDK := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
ifeq ($(strip $(SDK)),)
SDK := $(SDKROOT)
endif
CC   = xcrun -sdk iphoneos clang

# Core OverlayTweak sources
CORE_SOURCES = \
    OverlayEntry.m \
    OverlayManager.m \
    OverlayView.m \
    SettingsViewController.m

# CPM Automation sources. Keep this list explicit: a silently missing file links fine
# and only shows up as "unknown selector" at runtime inside the game.
CPM_CORE_SOURCES = \
    Core/CPMVinylShape.m \
    Core/CPMShapeDecomposer.m \
    Core/CPMTouchInjector.m \
    Core/CPMExecutionController.m \
    Core/CPMUICalibration.m \
    Core/CPMGameLayout.m \
    Core/CPMIl2CppBridge.m

CPM_UI_SOURCES = \
    UI/CPMAutoDrawViewController.m \
    UI/CPMROIOverlayView.m

SOURCES = $(CORE_SOURCES) $(CPM_CORE_SOURCES) $(CPM_UI_SOURCES)

CFLAGS = -isysroot "$(SDK)" \
        -miphoneos-version-min=$(MIN_IOS) \
        -fobjc-arc \
        -fvisibility=hidden \
        -O2 \
        -g0 \
        -I. \
        -I Core \
        -I UI \
        -Wno-deprecated-declarations \
        -Wno-unused-variable \
        -Wno-objc-missing-super-calls \
        -Wno-partial-availability

# Link frameworks
LDFLAGS = -isysroot "$(SDK)" \
          -miphoneos-version-min=$(MIN_IOS) \
          -dynamiclib \
          -lobjc \
          -framework UIKit \
          -framework Foundation \
          -framework Photos \
          -framework PhotosUI \
          -framework CoreGraphics \
          -framework QuartzCore \
          -framework CoreImage \
          -framework Accelerate \
          -framework IOKit \
          -install_name @executable_path/$(TARGET_NAME)

.PHONY: all clean check-sdk check layout layout-check anchors anchors-check sources

all: check-sdk
	@echo "[CC/LD] arm64"
	$(CC) $(CFLAGS) $(LDFLAGS) -arch arm64 -o $(TARGET_NAME).arm64 $(SOURCES)
	@echo "[CC/LD] arm64e (optional)"
	@if $(CC) $(CFLAGS) $(LDFLAGS) -arch arm64e -o $(TARGET_NAME).arm64e $(SOURCES); then \
		echo "[LIPO] arm64 + arm64e"; \
		lipo -create -output $(TARGET_NAME) $(TARGET_NAME).arm64 $(TARGET_NAME).arm64e; \
	else \
		echo "[WARN] arm64e failed — shipping arm64 only"; \
		cp $(TARGET_NAME).arm64 $(TARGET_NAME); \
	fi
	@rm -f $(TARGET_NAME).arm64 $(TARGET_NAME).arm64e
	@echo "[STRIP] $(TARGET_NAME)"
	@xcrun -sdk iphoneos strip -x $(TARGET_NAME) 2>/dev/null || true
	@echo ""
	@echo "=========================================="
	@echo "  Built: $(TARGET_NAME)"
	@lipo -info $(TARGET_NAME) || true
	@ls -lh $(TARGET_NAME)
	@echo "=========================================="
	@echo ""
	@echo "CPM Automation enabled: $(CPM_CORE_SOURCES) $(CPM_UI_SOURCES)"

check-sdk:
	@if [ -z "$(SDK)" ]; then \
		echo "ERROR: iOS SDK not found."; \
		echo "Install Xcode and run: xcode-select --install"; \
		echo "Then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
		exit 1; \
	fi
	@echo "[SDK] $(SDK)"

# --- generated code -----------------------------------------------------------
# Core/CPMGameLayout.{h,m} come from the IL2CPP dump; Core/CPMAnchorsDefault.h comes
# from Resources/cpm_ui_anchors.json. Both are committed, so a plain `make` works
# without dump.cs; these targets regenerate them.
DUMP ?= dump.cs

# python3 with the libclang bindings, used by the static checker. `make check` works without
# it (the checker prints SKIP); install with `python3 -m pip install libclang`.
CPM_PYTHON ?= $(shell test -x /tmp/venv/bin/python && echo /tmp/venv/bin/python || echo python3)

layout:
	@test -f "$(DUMP)" || { echo "ERROR: $(DUMP) not found (set DUMP=/path/to/dump.cs)"; exit 1; }
	@$(CPM_PYTHON) tools/cpm_il2cpp.py generate --dump "$(DUMP)"

layout-check:
	@test -f "$(DUMP)" || { echo "SKIP layout check: $(DUMP) not present"; exit 0; }
	@$(CPM_PYTHON) tools/cpm_il2cpp.py check --dump "$(DUMP)"

anchors:
	@$(CPM_PYTHON) tools/cpm_anchors.py generate

anchors-check:
	@$(CPM_PYTHON) tools/cpm_anchors.py check

# --- static checks -----------------------------------------------------------
check: anchors-check layout-check
	@python3 scripts/check_objc.py
	@$(CPM_PYTHON) tools/cpm_check.py --overlay

# Resolve every source the dylib needs (catches a missing file before the linker).
sources:
	@for f in $(SOURCES); do \
	  if [ ! -f "$$f" ]; then echo "ERROR: missing source $$f"; exit 1; fi; \
	  echo "  $$f"; \
	done
	@echo "[SOURCES] $(words $(SOURCES)) files"

clean:
	@rm -f $(SOURCES:.m=.o) $(TARGET_NAME) $(TARGET_NAME).arm64 $(TARGET_NAME).arm64e
	@echo "[CLEAN] done"

# Inject into an IPA (requires insert_dylib)
inject:
	@if [ ! -f "$(TARGET_NAME)" ]; then \
		echo "ERROR: $(TARGET_NAME) not built. Run 'make' first."; \
		exit 1; \
	fi
	@if [ -z "$(IPA_PATH)" ]; then \
		echo "Usage: make inject IPA_PATH=/path/to/game.ipa"; \
		exit 1; \
	fi
	@echo "[Inject] $(IPA_PATH) with $(TARGET_NAME)"
	@mkdir -p tools
	@if [ ! -f tools/insert_dylib ]; then \
		echo "[Clone] insert_dylib"; \
		git clone https://github.com/tyilo/insert_dylib.git /tmp/insert_dylib 2>/dev/null || true; \
		cc /tmp/insert_dylib/insert_dylib/main.c -o tools/insert_dylib; \
	fi
	@./scripts/inject.sh $(IPA_PATH) $(TARGET_NAME)
	@echo "[Done] $(IPA_PATH:.ipa=_injected.ipa)"

# Run tests (if available)
test:
	@echo "[Test] No automated tests configured"
	@echo "Manual testing required on device"

# Show CPM module info
cpm-info:
	@echo "CPM Image-to-Vinyl Automation Module"
	@echo "======================================"
	@echo "Game layout:  Core/CPMGameLayout.[hm]  (regenerate: make layout DUMP=dump.cs)"
	@$(CPM_PYTHON) tools/cpm_show_layout.py
	@echo "Anchors:      Core/CPMAnchorsDefault.h (regenerate: make anchors)"
	@echo "Shape types:  Square, Circle, Triangle, Line, Polygon, Text"
	@echo "Touch:        synthetic UIEvent to the game's input view (IOHID is opt-in)"
	@echo "Layer cap:    VinylsEditor._maxVinylsCount when the il2cpp bridge resolves"

# Build and display info
info:
	@echo "OverlayTweak v$(shell grep 'kOLVersion' OverlayCommon.h | head -1 | sed 's/.*@\"\\(.*\\)\".*/\\1/')"
	@echo "Sources: $(words $(SOURCES)) files"
	@echo "Core: $(words $(CORE_SOURCES)) files"
	@echo "CPM Core: $(words $(CPM_CORE_SOURCES)) files"
	@echo "CPM UI: $(words $(CPM_UI_SOURCES)) files"
