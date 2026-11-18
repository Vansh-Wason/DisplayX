# DisplayX: installs the Home with the theme in theme\config.json.
# Only Home's own helper is switched on (no volume bar). If the theme names a stock_home_redirect, that home stays enabled
# and hidden, because on Google TV it owns the quick panel behind the remote's Settings button.
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 -Serial <tv ip>:<port> [-Adb path]
# Build first (see README); this installs apk\displayx.apk.
# Undo:   adb uninstall <app id> (then your TV's own Home comes back). It installs beside the cleanyourtv launcher
#         (com.gathin.tvhome), never over it.
param(
    [Parameter(Mandatory = $true)][string]$Serial,
    # The app ID you built with (-PlauncherApplicationId); see README.
    [string]$Package = 'tv.displayx.home',
    [string]$Adb = ''
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $Adb) { $Adb = 'adb' }   # adb from Android platform-tools, on PATH
$pkg = $Package
$cls = 'com.gathin.tvhome'   # the code's own package: class names don't change with the app ID
$dir = "/sdcard/Android/data/$pkg/files"
$config = Join-Path $here 'theme\config.json'
if (-not (Test-Path $config)) { throw "No theme at $config" }
function Sh([string]$c) { & $Adb -s $Serial shell $c }

& $Adb connect $Serial | Out-Null
if ((& $Adb -s $Serial get-state 2>$null) -ne 'device') { throw "Cannot reach $Serial" }

& $Adb -s $Serial install -r (Join-Path $here 'apk\displayx.apk') | Out-Null
Sh "pm grant $pkg android.permission.READ_TV_LISTINGS; pm grant $pkg android.permission.READ_MEDIA_IMAGES"

# First start creates the app's folder for the theme. The old display font is no longer used.
Sh "am start -W -n $pkg/$cls.MainActivity" | Out-Null
# Many TVs keep their own home for the Home button even after another app is made Home: Google TV, older Android TV
# (tvlauncher) and brand launchers. Ask Android which app answers Home; if it isn't this one, the key helper sends Home on
# to this one (stock_home_redirect), and that home stays enabled (on Google TV it owns the quick panel behind the gear).
$theme = Get-Content $config -Raw | ConvertFrom-Json
Sh "cmd package set-home-activity --user 0 $pkg/$cls.MainActivity" | Out-Null
$answers = "$((Sh 'cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN') | Select-Object -Last 1)".Trim()
$stock = ($answers -split '/')[0]
if (-not $theme.stock_home_redirect -and $stock -and $stock -ne $pkg -and $stock -ne 'android') {
    $theme | Add-Member -NotePropertyName stock_home_redirect -NotePropertyValue $stock -Force
    Write-Host "Home button belongs to ${stock}: adding the redirect"
}
$redirect = $theme.stock_home_redirect
$pushed = Join-Path $env:TEMP 'displayx-config.json'
[IO.File]::WriteAllText($pushed, ($theme | ConvertTo-Json -Depth 8))   # theme\config.json itself is left as it is
& $Adb -s $Serial push $pushed /data/local/tmp/po-config.json | Out-Null
Remove-Item $pushed
$rev = [guid]::NewGuid().ToString('N')
Sh "cp /data/local/tmp/po-config.json $dir/config.json; rm -f $dir/hero_font.ttf; printf '%s' '$rev' > $dir/theme_revision; rm -f /data/local/tmp/po-config.json"
Sh "am force-stop $pkg"

# A reinstall or force-stop unbinds the helper, so it is taken off the list and put back. Every other accessibility
# service on the TV (TalkBack, a remote app's) stays exactly as it was.
$helper = "$pkg/$cls.HomeKeyService"
$current = ((Sh 'settings get secure enabled_accessibility_services') | Out-String).Trim()
$others = @($current -split ':' | Where-Object { $_ -and $_ -ne 'null' -and $_ -ne $helper })
$without = $others -join ':'
$with = (@($others) + $helper) -join ':'
Sh "cmd notification allow_listener $pkg/$cls.GuardRevival"
Sh "settings put secure enabled_accessibility_services '$without'; sleep 1; settings put secure enabled_accessibility_services '$with'; settings put secure accessibility_enabled 1"
if ($redirect) { Sh "pm enable $redirect" | Out-Null }
Sh "cmd package set-home-activity --user 0 $pkg/$cls.MainActivity" | Out-Null
Start-Sleep -Seconds 3

# The redirect fires on a window change, so step away and come back.
Sh 'am start -a android.settings.SETTINGS' | Out-Null
Start-Sleep -Seconds 3
Sh 'input keyevent KEYCODE_HOME'
Start-Sleep -Seconds 6
# Android 10 and later call the front app topResumedActivity; Android 8 and 9 call it mResumedActivity.
$front = "$((Sh 'dumpsys activity activities' | Select-String 'topResumedActivity|mResumedActivity' | Select-Object -First 1).Line)".Trim()
Write-Host "In front: $front"
if ($front -notmatch $pkg) { throw 'The Home is not in front: press Home on the remote, then check again.' }
