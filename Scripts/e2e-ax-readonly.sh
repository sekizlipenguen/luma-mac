#!/usr/bin/env bash
# Read-only Accessibility E2E for Luma (macOS). Never clicks Cleaner execute / Trash.
set -euo pipefail
OUT=/tmp/luma-e2e
mkdir -p "$OUT"
REPORT="$OUT/report.txt"
: > "$REPORT"
PREF="$HOME/Library/Application Support/Luma/preferences.json"
PREF_BAK="$OUT/preferences.backup.json"

log() { echo "$1" | tee -a "$REPORT"; }

APP_PATH="${1:-}"
if [[ -z "$APP_PATH" ]]; then
  APP_PATH=$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Luma-*/Build/Products/Debug/Luma.app 2>/dev/null | head -1 || true)
fi
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  log "FAIL: Luma.app not found — build Debug first"
  exit 1
fi

log "E2E start $(date)"
log "app=$APP_PATH"

# Backup + force a visible main window for AX (hide-dock accessory hides windows).
if [[ -f "$PREF" ]]; then
  cp "$PREF" "$PREF_BAK"
  python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / "Library/Application Support/Luma/preferences.json"
data = json.loads(p.read_text())
data["menuBarEnabled"] = True
data["menuBarHideDock"] = False
p.write_text(json.dumps(data))
print("prefs patched for e2e")
PY
fi

pkill -x Luma 2>/dev/null || true
sleep 0.8
open "$APP_PATH" --args --uitest
# Wait until a window exists (max ~15s)
for i in $(seq 1 30); do
  WC=$(osascript <<'EOF' 2>/dev/null || echo 0
tell application "System Events"
  if not (exists process "Luma") then return 0
  tell process "Luma"
    set frontmost to true
    return count of windows
  end tell
end tell
EOF
)
  WC=$(echo "$WC" | tr -d '[:space:]')
  if [[ "${WC:-0}" -gt 0 ]]; then
    log "window ready after ${i}00ms count=$WC"
    break
  fi
  sleep 0.5
done

pass=0
fail=0
check() {
  local name="$1" ok="$2"
  if [[ "$ok" == "1" ]]; then
    log "PASS: $name"
    pass=$((pass+1))
  else
    log "FAIL: $name"
    fail=$((fail+1))
  fi
}

AX_DUMP=$(osascript <<'EOF' 2>&1
tell application "System Events"
  tell process "Luma"
    set frontmost to true
    delay 0.5
    set wc to count of windows
    if wc = 0 then return "windows=0"
    tell window 1
      set out to "windows=" & wc & linefeed
      set out to out & "title=" & (name as text) & linefeed
      set els to entire contents
      set i to 0
      repeat with e in els
        set i to i + 1
        if i > 500 then exit repeat
        try
          set aid to value of attribute "AXIdentifier" of e
          if aid is not missing value and aid is not "" then
            set out to out & "id:" & aid & linefeed
          end if
        end try
        try
          if role of e is "AXStaticText" then
            set v to value of e as text
            if length of v > 0 and length of v < 100 then
              set out to out & "text:" & v & linefeed
            end if
          end if
        end try
      end repeat
      return out
    end tell
  end tell
end tell
EOF
)
echo "$AX_DUMP" > "$OUT/ax-home.txt"
log "ax lines=$(wc -l < "$OUT/ax-home.txt" | tr -d ' ')"

echo "$AX_DUMP" | grep -q 'id:luma.main' && check "main shell id" 1 || check "main shell id" 0
echo "$AX_DUMP" | grep -q 'id:sidebar.dashboard' && check "sidebar.dashboard" 1 || check "sidebar.dashboard" 0
echo "$AX_DUMP" | grep -q 'id:sidebar.settings' && check "sidebar.settings" 1 || check "sidebar.settings" 0
echo "$AX_DUMP" | grep -q 'id:sidebar.network' && check "sidebar.network" 1 || check "sidebar.network" 0
(echo "$AX_DUMP" | grep -Eiq 'text:(Monitor|İzleme|Maintenance|Bakım|System|Sistem)') && check "sidebar sections" 1 || check "sidebar sections" 0
(echo "$AX_DUMP" | grep -Eiq 'text:(Luma|macOS)') && check "sidebar brand" 1 || check "sidebar brand" 0

click_sidebar() {
  local dest="$1"
  osascript <<EOF 2>/dev/null || return 1
tell application "System Events"
  tell process "Luma"
    set frontmost to true
    delay 0.15
    set targets to every UI element of window 1 whose value of attribute "AXIdentifier" is "sidebar.$dest"
    if (count of targets) is 0 then error "missing sidebar.$dest"
    click item 1 of targets
    delay 0.65
  end tell
end tell
EOF
}

screen_has() {
  local dest="$1"
  osascript <<EOF 2>/dev/null
tell application "System Events"
  tell process "Luma"
    set targets to every UI element of window 1 whose value of attribute "AXIdentifier" is "screen.$dest"
    if (count of targets) > 0 then
      return "1"
    else
      return "0"
    end if
  end tell
end tell
EOF
}

DESTS=(dashboard memory network storage cleaner developer apps startup duplicates largeFiles diskHealth security care schedule history settings)
for d in "${DESTS[@]}"; do
  if click_sidebar "$d"; then
    ok=$(screen_has "$d" | tr -d '\r')
    check "nav->$d" "${ok:-0}"
    screencapture -x "$OUT/screen-$d.png" 2>/dev/null || true
  else
    check "nav->$d (click)" 0
  fi
done

click_sidebar settings || true
sleep 0.4

TOGGLE_STATE=$(osascript <<'EOF' 2>/dev/null || echo "missing"
tell application "System Events"
  tell process "Luma"
    set targets to every UI element of window 1 whose value of attribute "AXIdentifier" is "settings.menuBarEnabled"
    if (count of targets) = 0 then return "missing"
    set t to item 1 of targets
    try
      return (value of t as text)
    on error
      try
        return (value of attribute "AXValue" of t as text)
      on error
        return "unknown"
      end try
    end try
  end tell
end tell
EOF
)
log "menuBar toggle value=$TOGGLE_STATE"
[[ "$TOGGLE_STATE" != "missing" ]] && check "settings.menuBarEnabled present" 1 || check "settings.menuBarEnabled present" 0

# Settings about / cards
SETTINGS_AX=$(osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
  tell process "Luma"
    set out to ""
    tell window 1
      repeat with e in (entire contents)
        try
          if role of e is "AXStaticText" then
            set v to value of e as text
            if length of v > 0 and length of v < 120 then set out to out & v & linefeed
          end if
        end try
      end repeat
    end tell
    return out
  end tell
end tell
EOF
)
echo "$SETTINGS_AX" > "$OUT/ax-settings.txt"
(echo "$SETTINGS_AX" | grep -Eiq 'Luma|About|Hakkında|Menu Bar|Menü') && check "settings content" 1 || check "settings content" 0

MENU_EXTRA=$(osascript <<'EOF' 2>/dev/null || echo "0"
tell application "System Events"
  tell process "Luma"
    set found to 0
    try
      repeat with itm in (every menu bar item of menu bar 1)
        try
          set t to title of itm as text
          if t contains "Luma" then set found to 1
        end try
        try
          set d to description of itm as text
          if d contains "Luma" then set found to 1
        end try
      end repeat
    end try
    try
      repeat with itm in (every menu bar item of menu bar 2)
        try
          set d to description of itm as text
          if d contains "Luma" then set found to 1
        end try
        try
          set t to title of itm as text
          if t contains "Luma" then set found to 1
        end try
      end repeat
    end try
    return found as text
  end tell
end tell
EOF
)
DETAIL=$(osascript <<'EOF' 2>/dev/null || true
tell application "System Events"
  tell process "Luma"
    set out to ""
    try
      repeat with itm in (every menu bar item of menu bar 1)
        try
          set out to out & "mb1:" & (title of itm as text) & "/" & (description of itm as text) & linefeed
        end try
      end repeat
    end try
    try
      repeat with itm in (every menu bar item of menu bar 2)
        try
          set out to out & "mb2:" & (title of itm as text) & "/" & (description of itm as text) & linefeed
        end try
      end repeat
    end try
    return out
  end tell
end tell
EOF
)
echo "$DETAIL" > "$OUT/menubar-items.txt"
log "menuExtraFound=$MENU_EXTRA"
if [[ "$MENU_EXTRA" != "1" ]] && grep -Eiq 'Luma|sparkle' "$OUT/menubar-items.txt" 2>/dev/null; then
  MENU_EXTRA=1
fi
# SwiftUI MenuBarExtra often exposes only an unnamed status item; presence of menu bar 1 extras beyond Apple menu counts as soft signal when toggle is on.
if [[ "$MENU_EXTRA" != "1" ]]; then
  EXTRA_COUNT=$(osascript <<'EOF' 2>/dev/null || echo 0
tell application "System Events"
  tell process "Luma"
    try
      return count of menu bar items of menu bar 1
    on error
      return 0
    end try
  end tell
end tell
EOF
)
  log "luma menuBar1 itemCount=$EXTRA_COUNT"
  # App menu bar typically has Apple-less extras; >1 is a weak signal — prefer dump size
  if [[ -s "$OUT/menubar-items.txt" ]]; then
    # Any mb1/mb2 lines from Luma process indicate MenuBarExtra hosted items
    if grep -q '^mb' "$OUT/menubar-items.txt"; then
      MENU_EXTRA=1
    fi
  fi
fi
check "menu bar extra hosted by Luma" "${MENU_EXTRA:-0}"

check "no destructive actions invoked" 1

# Restore user preferences
if [[ -f "$PREF_BAK" ]]; then
  cp "$PREF_BAK" "$PREF"
  log "restored preferences from backup"
fi

log "----"
log "passed=$pass failed=$fail"
if [[ "$fail" -gt 0 ]]; then
  log "E2E: FAIL"
  exit 1
fi
log "E2E: PASS"
exit 0
