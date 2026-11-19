#!/usr/bin/env bash
# DisplayX installer for macOS and Linux: one command from a computer on the same Wi-Fi as the TV.
#   bash install.sh <tv ip>:<port>
# On the TV first: Settings > System > About > press Build 7 times; then Developer options > Wireless debugging: on.
# Four optional choices (wallpapers, name, weather, update notes), each showing its cost; Enter keeps each off.
# Set QUIET=1 to skip them, or answer them ahead: WALLPAPERS=<folder> NAME=<name> WEATHER=<lat,lon> UPDATE_NOTICE=yes|no
# Undo: adb uninstall tv.displayx.home (your TV's previous Home comes back).
set -euo pipefail

TV="${1:-}"
[ -n "$TV" ] || { echo "Usage: bash install.sh <address shown under Wireless debugging, e.g. 192.168.1.50:41234>"; exit 1; }
PKG="${PACKAGE:-tv.displayx.home}"
REPO="${REPO:-Vansh-Wason/DisplayX}"
CLS=com.gathin.tvhome            # the code's own package; class names don't change with the app ID
HERE="$(cd "$(dirname "$0")" && pwd)"
WALLPAPERS="${WALLPAPERS:-}"; NAME="${NAME:-}"; WEATHER="${WEATHER:-}"; UPDATE_NOTICE="${UPDATE_NOTICE:-}"
step() { printf '\n\033[36m>> %s\033[0m\n' "$1"; }
ask() { local a; read -r -p "$1: " a < /dev/tty; printf '%s' "$a" | sed 's/^ *//; s/ *$//'; }

# Prints the chosen number (1 = first, also for Enter). QUIET=1 always picks 1.
choose() {
    local title="$1"; shift
    [ "${QUIET:-}" = 1 ] && { echo 1; return; }
    printf '\n%s\n' "$title" > /dev/tty
    local i=1; for o in "$@"; do printf '  %d. %s\n' "$i" "$o" > /dev/tty; i=$((i + 1)); done
    local n; read -r -p "Choose 1-$# (Enter = 1): " n < /dev/tty
    case "$n" in ''|*[!0-9]*) echo 1 ;; *) if [ "$n" -ge 1 ] && [ "$n" -le $# ]; then echo "$n"; else echo 1; fi ;; esac
}

# 1. adb: on PATH, else Google's official platform-tools, downloaded once into ./tools.
step 'Finding adb'
ADB="${ADB:-$(command -v adb || true)}"
if [ -z "$ADB" ]; then
    ADB="$HERE/tools/platform-tools/adb"
    if [ ! -x "$ADB" ]; then
        case "$(uname -s)" in Darwin) os=darwin ;; *) os=linux ;; esac
        mkdir -p "$HERE/tools"
        curl -fsSL "https://dl.google.com/android/repository/platform-tools-latest-$os.zip" -o "$HERE/tools/pt.zip"
        unzip -qo "$HERE/tools/pt.zip" -d "$HERE/tools" && rm "$HERE/tools/pt.zip"
    fi
fi
sh_tv() { "$ADB" -s "$TV" shell "$1"; }

# 2. Connect, pairing first if this computer has never paired with the TV.
step "Connecting to $TV"
"$ADB" connect "$TV" > /dev/null 2>&1 || true
if [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
    pair_at="${PAIR_AT:-$(ask 'Not paired yet. On the TV open Wireless debugging > Pair device with pairing code. Address shown there')}"
    pair_code="${PAIR_CODE:-$(ask 'Pairing code')}"
    "$ADB" pair "$pair_at" "$pair_code" || true
    "$ADB" connect "$TV" > /dev/null 2>&1 || true
    if [ "$("$ADB" -s "$TV" get-state 2>/dev/null)" != device ]; then
        echo "Can't reach the TV at $TV. Same Wi-Fi? Wireless debugging still on?"
        [ "$(uname -s)" = Darwin ] && echo "On a Mac, \"No route to host\" means macOS blocked it: System Settings > Privacy & Security > Local Network > turn on your terminal app, then run this again."
        exit 1
    fi
fi

# 3. The app: apk/displayx.apk if you built one, else the newest release.
APK="$HERE/apk/displayx.apk"
if [ ! -f "$APK" ]; then
    step 'Downloading the newest DisplayX'
    mkdir -p "$HERE/apk"
    curl -fsSL "https://github.com/$REPO/releases/latest/download/displayx.apk" -o "$APK"
fi

# 4. Four optional choices. Each says what it does and what it costs; Enter keeps it off.
if [ -z "$WALLPAPERS" ] && [ "$(choose 'Wallpapers' 'DisplayX set: 4 photos, nothing to set up' 'My own photos: pick a folder on this computer')" = 2 ]; then
    WALLPAPERS="$(ask 'Folder of photos')"
fi
if [ -z "$NAME" ] && [ "$(choose 'Name in the greeting' 'No name: "Good evening."' 'Add a name: "Good evening, Sam."  (stays on the TV only)')" = 2 ]; then
    NAME="$(ask 'Name')"
fi
latlon() { LC_ALL=C printf '%.1f,%.1f' "$1" "$2"; }   # about 10 km
if [ -z "$WEATHER" ]; then
    w="$(choose 'Weather in the greeting  (without it, greetings follow the time of day)' \
        'Off: nothing goes online for weather' \
        'On, find my city automatically: this computer asks ipwho.is once; the TV then checks open-meteo.com hourly (a few KB)' \
        'On, I will type my city: looked up once on open-meteo.com; the TV then checks hourly (a few KB)')"
    if [ "$w" = 2 ]; then
        at="$(curl -fsS 'https://ipwho.is/?fields=success,city,latitude,longitude' || true)"
        lat="$(printf '%s' "$at" | sed -n 's/.*"latitude":\(-\{0,1\}[0-9.]*\).*/\1/p')"
        lon="$(printf '%s' "$at" | sed -n 's/.*"longitude":\(-\{0,1\}[0-9.]*\).*/\1/p')"
        if [ -n "$lat" ] && [ -n "$lon" ]; then WEATHER="$(latlon "$lat" "$lon")"; echo "  Found: $(printf '%s' "$at" | sed -n 's/.*"city":"\([^"]*\)".*/\1/p'), rounded to about 10 km."; fi
    elif [ "$w" = 3 ]; then
        city="$(ask 'City')"
        hit="$(curl -fsSG 'https://geocoding-api.open-meteo.com/v1/search' --data-urlencode "name=$city" -d count=1 || true)"
        lat="$(printf '%s' "$hit" | sed -n 's/.*"latitude":\(-\{0,1\}[0-9.]*\).*/\1/p')"
        lon="$(printf '%s' "$hit" | sed -n 's/.*"longitude":\(-\{0,1\}[0-9.]*\).*/\1/p')"
        if [ -n "$lat" ] && [ -n "$lon" ]; then WEATHER="$(latlon "$lat" "$lon")"; echo "  Found: $city."; fi
    fi
    [ "$w" != 1 ] && [ -z "$WEATHER" ] && echo '  Could not look that up; weather stays off. You can run the installer again later.'
fi
if [ -z "$UPDATE_NOTICE" ]; then
    UPDATE_NOTICE=no
    [ "$(choose 'Update notes' 'Off: never checks' 'On: once a day the TV asks GitHub if there is a newer DisplayX (about 2 KB) and says so in the greeting. It never installs anything by itself')" = 2 ] && UPDATE_NOTICE=yes
fi

# 5. Install.
step 'Installing'
"$ADB" -s "$TV" install -r "$APK" > /dev/null
sh_tv "pm grant $PKG android.permission.READ_TV_LISTINGS; pm grant $PKG android.permission.READ_MEDIA_IMAGES 2>/dev/null; pm grant $PKG android.permission.READ_EXTERNAL_STORAGE 2>/dev/null; true"
sh_tv "am start -W -n $PKG/$CLS.MainActivity" > /dev/null 2>&1 || true

# 6. Wallpapers into the TV's Pictures/TV_Wallpapers.
step 'Adding wallpapers'
src="${WALLPAPERS:-$HERE/wallpapers}"
sh_tv 'mkdir -p /sdcard/Pictures/TV_Wallpapers'
find "$src" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | while IFS= read -r p; do
    n="$(basename "$p")"
    "$ADB" -s "$TV" push "$p" "/sdcard/Pictures/TV_Wallpapers/$n" > /dev/null 2>&1 || { echo "Could not copy $p to the TV."; exit 1; }
    sh_tv "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file:///sdcard/Pictures/TV_Wallpapers/$n'" > /dev/null
done

# 7. The theme with your answers. Many TVs keep their own home for the Home button even after another is chosen:
#    if so, the key helper sends Home on to DisplayX.
json_str() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
extra=""
[ -n "$NAME" ] && extra="$extra  \"greeting_name\": $(json_str "$NAME"),\n"
[ -n "$WEATHER" ] && extra="$extra  \"weather_location\": $(json_str "$WEATHER"),\n"
[ "$UPDATE_NOTICE" = yes ] && extra="$extra  \"update_repo\": $(json_str "$REPO"),\n"
sh_tv "cmd package set-home-activity --user 0 $PKG/$CLS.MainActivity" > /dev/null 2>&1 || true
stock="$(sh_tv 'cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN' | tail -n 1 | tr -d '\r' | cut -d/ -f1)"
if [ -n "$stock" ] && [ "$stock" != "$PKG" ] && [ "$stock" != android ] && ! grep -q '"stock_home_redirect"' "$HERE/theme/config.json"; then
    extra="$extra  \"stock_home_redirect\": $(json_str "$stock"),\n"
fi
tmp="$(mktemp)"
# The answers first, then the theme's own keys (everything after its opening brace).
{ echo '{'; printf '%b' "$extra"; awk 'f { print; next } /\{/ { f = 1; sub(/[^{]*\{/, ""); if (length($0)) print }' "$HERE/theme/config.json"; } > "$tmp"
dir="/sdcard/Android/data/$PKG/files"
"$ADB" -s "$TV" push "$tmp" /data/local/tmp/dx.json > /dev/null 2>&1 || { echo 'Could not copy the theme to the TV.'; exit 1; }
rm -f "$tmp"
sh_tv "mkdir -p $dir; cp /data/local/tmp/dx.json $dir/config.json; printf '%s' '$(date +%s)$RANDOM' > $dir/theme_revision; rm -f /data/local/tmp/dx.json"
sh_tv "am force-stop $PKG"

# 8. The Home key helper, keeping every other accessibility service (TalkBack and others) as it was.
helper="$PKG/$CLS.HomeKeyService"
others="$(sh_tv 'settings get secure enabled_accessibility_services' | tr -d '\r' | tr ':' '\n' | grep -v -e '^null$' -e '^$' -e "^$helper\$" | paste -sd: - || true)"
sh_tv "cmd notification allow_listener $PKG/$CLS.GuardRevival" > /dev/null 2>&1 || true
sh_tv "settings put secure enabled_accessibility_services '$others'; sleep 1; settings put secure enabled_accessibility_services '${others:+$others:}$helper'; settings put secure accessibility_enabled 1"
[ -n "$stock" ] && [ "$stock" != "$PKG" ] && [ "$stock" != android ] && sh_tv "pm enable $stock" > /dev/null 2>&1 || true

# 9. Done: step away and press Home, as you would on the remote.
sh_tv 'am start -a android.settings.SETTINGS' > /dev/null 2>&1 || true
sleep 3
sh_tv 'input keyevent KEYCODE_HOME'
sleep 5
if sh_tv 'dumpsys activity activities' | grep -E 'topResumedActivity|mResumedActivity' | head -n 1 | grep -q "$PKG"; then
    printf '\n\033[32mDone. DisplayX is your Home.\033[0m\n'
else
    printf '\n\033[33mInstalled. Press Home on the remote; if your old Home appears, press it once more.\033[0m\n'
fi
echo 'When you are finished, turn Wireless debugging off on the TV.'
