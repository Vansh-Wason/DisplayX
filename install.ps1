# DisplayX installer: one command from a Windows PC on the same Wi-Fi as the TV.
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Tv <tv ip>:<port>
# On the TV first: Settings > System > About > press Build 7 times; then Developer options > Wireless debugging: on.
# It asks four questions (wallpapers, name, weather, update notice); pass them as options to skip the questions.
# Undo: adb uninstall tv.displayx.home (your TV's previous Home comes back).
param(
    [Parameter(Mandatory = $true)][string]$Tv,       # the address under Wireless debugging, e.g. 192.168.1.50:41234
    [string]$PairCode = '',                          # from Wireless debugging > Pair device with pairing code
    [string]$PairAt = '',                            # the address shown on that pairing screen
    [string]$Wallpapers = '',                        # a folder of your photos; empty = DisplayX's AMOLED set
    [string]$Name = '',
    [string]$Weather = '',                           # "lat,lon", e.g. 51.5,-0.1; empty = no weather, nothing online
    [ValidateSet('', 'yes', 'no')][string]$UpdateNotice = '',
    [string]$Package = 'tv.displayx.home',
    [string]$Repo = 'displayx-tv/DisplayX',          # where releases come from
    [string]$Adb = '',                               # adb to use; empty = on PATH, else Google's, downloaded once
    [switch]$Quiet                                   # no questions: use the options as given
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$cls = 'com.gathin.tvhome'                           # the code's own package; class names don't change with the app ID
function Ask([string]$q, [string]$now) { if ($Quiet -or $now) { return $now } ; return (Read-Host $q).Trim() }
function Step([string]$t) { Write-Host "`n>> $t" -ForegroundColor Cyan }

# 1. adb: given, on PATH, here, or Google's official platform-tools (downloaded once into .\tools).
Step 'Finding adb'
if (-not $Adb) { $Adb = (Get-Command adb -ErrorAction SilentlyContinue).Source }
if (-not $Adb) { $Adb = Join-Path $here 'tools\platform-tools\adb.exe' }
if (-not (Test-Path $Adb)) {
    $zip = Join-Path $env:TEMP 'platform-tools.zip'
    Invoke-WebRequest 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip
    Expand-Archive $zip (Join-Path $here 'tools') -Force
    Remove-Item $zip
}
function Sh([string]$c) { & $Adb -s $Tv shell $c }

# 2. Connect, pairing first if this PC has never paired with the TV.
Step "Connecting to $Tv"
& $Adb connect $Tv | Out-Null
if ((& $Adb -s $Tv get-state 2>$null) -ne 'device') {
    $PairAt = Ask 'Not paired yet. On the TV open Wireless debugging > Pair device with pairing code. Address shown there' $PairAt
    $PairCode = Ask 'Pairing code' $PairCode
    & $Adb pair $PairAt $PairCode
    & $Adb connect $Tv | Out-Null
    if ((& $Adb -s $Tv get-state 2>$null) -ne 'device') { throw "Can't reach the TV at $Tv. Same Wi-Fi? Wireless debugging still on?" }
}

# 3. The app: apk\displayx.apk if you built one, else the newest release.
$apk = Join-Path $here 'apk\displayx.apk'
if (-not (Test-Path $apk)) {
    Step 'Downloading the newest DisplayX'
    New-Item -ItemType Directory -Force (Split-Path $apk) | Out-Null
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like '*.apk' } | Select-Object -First 1
    Invoke-WebRequest $asset.browser_download_url -OutFile $apk
}

# 4. Four questions.
$Wallpapers = Ask 'Folder of photos to use as wallpapers (Enter = DisplayX''s own AMOLED set)' $Wallpapers
$Name = Ask 'Your name for the greeting (Enter to skip)' $Name
$Weather = Ask 'Weather in the greeting? Your city as lat,lon, e.g. 51.5,-0.1 (Enter = no weather, nothing goes online)' $Weather
if (-not $UpdateNotice) {
    $UpdateNotice = if ((Ask 'Show a note on the TV when a new DisplayX is out? (y/N)' $(if ($Quiet) { 'n' } else { '' })) -match '^y') { 'yes' } else { 'no' }
}

# 5. Install.
Step 'Installing'
& $Adb -s $Tv install -r $apk | Out-Null
Sh "pm grant $Package android.permission.READ_TV_LISTINGS; pm grant $Package android.permission.READ_MEDIA_IMAGES"
Sh "am start -W -n $Package/$cls.MainActivity" | Out-Null

# 6. Wallpapers into the TV's Pictures/TV_Wallpapers.
Step 'Adding wallpapers'
$pics = if ($Wallpapers) { Get-ChildItem $Wallpapers -File -Recurse | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' } }
        else { Get-ChildItem (Join-Path $here 'wallpapers') -File }
Sh 'mkdir -p /sdcard/Pictures/TV_Wallpapers'
foreach ($p in $pics) {
    & $Adb -s $Tv push $p.FullName "/sdcard/Pictures/TV_Wallpapers/$($p.Name)" | Out-Null
    Sh "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d 'file:///sdcard/Pictures/TV_Wallpapers/$($p.Name)'" | Out-Null
}

# 7. The theme with your answers. Many TVs keep their own home for the Home button even after another is chosen
#    (Google TV, older Android TV, brand launchers): if so, the key helper sends Home on to DisplayX.
$theme = Get-Content (Join-Path $here 'theme\config.json') -Raw | ConvertFrom-Json
if ($Name) { $theme | Add-Member greeting_name $Name -Force }
if ($Weather) { $theme | Add-Member weather_location $Weather -Force }
if ($UpdateNotice -eq 'yes') { $theme | Add-Member update_repo $Repo -Force }
Sh "cmd package set-home-activity --user 0 $Package/$cls.MainActivity" | Out-Null
$answers = "$((Sh 'cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN') | Select-Object -Last 1)".Trim()
$stock = ($answers -split '/')[0]
if (-not $theme.stock_home_redirect -and $stock -and $stock -ne $Package -and $stock -ne 'android') {
    $theme | Add-Member stock_home_redirect $stock -Force
}
$tmp = Join-Path $env:TEMP 'displayx-config.json'
[IO.File]::WriteAllText($tmp, ($theme | ConvertTo-Json -Depth 8))
$dir = "/sdcard/Android/data/$Package/files"
& $Adb -s $Tv push $tmp /data/local/tmp/dx.json | Out-Null
Remove-Item $tmp
Sh "cp /data/local/tmp/dx.json $dir/config.json; printf '%s' '$([guid]::NewGuid().ToString('N'))' > $dir/theme_revision; rm -f /data/local/tmp/dx.json"
Sh "am force-stop $Package"

# 8. The Home key helper, keeping every other accessibility service (TalkBack and others) as it was.
$helper = "$Package/$cls.HomeKeyService"
$others = @(("$(Sh 'settings get secure enabled_accessibility_services')".Trim() -split ':') | Where-Object { $_ -and $_ -ne 'null' -and $_ -ne $helper })
Sh "cmd notification allow_listener $Package/$cls.GuardRevival"
Sh "settings put secure enabled_accessibility_services '$($others -join ':')'; sleep 1; settings put secure enabled_accessibility_services '$((@($others) + $helper) -join ':')'; settings put secure accessibility_enabled 1"
if ($theme.stock_home_redirect) { Sh "pm enable $($theme.stock_home_redirect)" | Out-Null }

# 9. Done: step away and press Home, as you would on the remote.
Sh 'am start -a android.settings.SETTINGS' | Out-Null
Start-Sleep 3
Sh 'input keyevent KEYCODE_HOME'
Start-Sleep 5
$front = "$((Sh 'dumpsys activity activities' | Select-String 'topResumedActivity|mResumedActivity' | Select-Object -First 1).Line)"
if ($front -match [regex]::Escape($Package)) { Write-Host "`nDone. DisplayX is your Home." -ForegroundColor Green }
else { Write-Host "`nInstalled. Press Home on the remote; if your old Home appears, press it once more." -ForegroundColor Yellow }
Write-Host 'When you are finished, turn Wireless debugging off on the TV.'
