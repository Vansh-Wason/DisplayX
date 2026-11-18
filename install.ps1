# DisplayX installer: one command from a Windows PC on the same Wi-Fi as the TV.
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Tv <tv ip>:<port>
# On the TV first: Settings > System > About > press Build 7 times; then Developer options > Wireless debugging: on.
# Four optional choices (wallpapers, name, weather, update notes), each showing its cost; Enter keeps each off. Pass options or -Quiet to skip them.
# Undo: adb uninstall tv.displayx.home (your TV's previous Home comes back).
param(
    [Parameter(Mandatory = $true)][string]$Tv,       # the address under Wireless debugging, e.g. 192.168.1.50:41234
    [string]$PairCode = '',                          # from Wireless debugging > Pair device with pairing code
    [string]$PairAt = '',                            # the address shown on that pairing screen
    [string]$Wallpapers = '',                        # a folder of your photos; empty = DisplayX's photo set
    [string]$Name = '',
    [string]$Weather = '',                           # "lat,lon", e.g. 51.5,-0.1; empty = no weather, nothing online
    [ValidateSet('', 'yes', 'no')][string]$UpdateNotice = '',
    [string]$Package = 'tv.displayx.home',
    [string]$Repo = 'Vansh-Wason/DisplayX',          # where releases come from
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
# adb writes progress and harmless warnings on stderr, which 'Stop' would treat as failures when output is captured.
function Sh([string]$c) { $ErrorActionPreference = 'Continue'; & $Adb -s $Tv shell $c }
function Push([string]$from, [string]$to) {
    $ErrorActionPreference = 'Continue'
    & $Adb -s $Tv push $from $to 2>&1 | Out-Null
    if ($LASTEXITCODE) { throw "Could not copy $from to the TV." }
}

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

# 4. Four optional choices. Each says what it does and what it costs; Enter on the first keeps it off.
function Choose([string]$title, [string[]]$options) {
    if ($Quiet) { return 0 }
    Write-Host "`n$title" -ForegroundColor White
    $pick = 0
    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }
    if (-not $interactive) {   # no live console (an editor's terminal): numbers instead of arrows
        for ($i = 0; $i -lt $options.Count; $i++) { Write-Host "  $($i + 1). $($options[$i])" }
        $n = Read-Host "Choose 1-$($options.Count) (Enter = 1)"
        if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $options.Count) { return [int]$n - 1 }
        return 0
    }
    $top = [Console]::CursorTop
    while ($true) {
        [Console]::SetCursorPosition(0, $top)
        for ($i = 0; $i -lt $options.Count; $i++) {
            $line = $(if ($i -eq $pick) { ' > ' } else { '   ' }) + $options[$i]
            Write-Host $line.PadRight([Console]::WindowWidth - 1) -ForegroundColor $(if ($i -eq $pick) { 'Cyan' } else { 'Gray' })
        }
        Write-Host '   (arrow keys, then Enter)'.PadRight([Console]::WindowWidth - 1) -ForegroundColor DarkGray
        $k = [Console]::ReadKey($true).Key
        if ($k -eq 'UpArrow') { $pick = ($pick + $options.Count - 1) % $options.Count }
        elseif ($k -eq 'DownArrow') { $pick = ($pick + 1) % $options.Count }
        elseif ($k -eq 'Enter') { return $pick }
    }
}

if (-not $Wallpapers -and (Choose 'Wallpapers' @(
        'DisplayX set: 4 photos, nothing to set up',
        'My own photos: pick a folder on this PC')) -eq 1) {
    $Wallpapers = Ask 'Folder of photos' ''
}

if (-not $Name -and (Choose 'Name in the greeting' @(
        'No name: "Good evening."',
        'Add a name: "Good evening, Sam."  (stays on the TV only)')) -eq 1) {
    $Name = Ask 'Name' ''
}

if (-not $Weather) {
    $w = Choose 'Weather in the greeting  (without it, greetings follow the time of day)' @(
        'Off: nothing goes online for weather',
        'On, find my city automatically: this PC asks ipwho.is once; the TV then checks open-meteo.com hourly (a few KB)',
        'On, I will type my city: looked up once on open-meteo.com; the TV then checks hourly (a few KB)')
    try {
        if ($w -eq 1) {
            $at = Invoke-RestMethod 'https://ipwho.is/?fields=success,city,latitude,longitude'
            if ($at.success) { $Weather = [string]::Format([cultureinfo]::InvariantCulture, '{0:0.0},{1:0.0}', $at.latitude, $at.longitude); Write-Host "  Found: $($at.city), rounded to about 10 km." }
        } elseif ($w -eq 2) {
            $city = Ask 'City' ''
            $hit = (Invoke-RestMethod "https://geocoding-api.open-meteo.com/v1/search?count=1&name=$([uri]::EscapeDataString($city))").results | Select-Object -First 1
            if ($hit) { $Weather = [string]::Format([cultureinfo]::InvariantCulture, '{0:0.0},{1:0.0}', $hit.latitude, $hit.longitude); Write-Host "  Found: $($hit.name), $($hit.country)." }
        }
    } catch { Write-Host '  Could not look that up; weather stays off. You can run the installer again later.' -ForegroundColor Yellow }
}

if (-not $UpdateNotice) {
    $UpdateNotice = if ((Choose 'Update notes' @(
            'Off: never checks',
            'On: once a day the TV asks GitHub if there is a newer DisplayX (about 2 KB) and says so in the greeting. It never installs anything by itself')) -eq 1) { 'yes' } else { 'no' }
}

# 5. Install.
Step 'Installing'
& $Adb -s $Tv install -r $apk | Out-Null
Sh "pm grant $Package android.permission.READ_TV_LISTINGS; pm grant $Package android.permission.READ_MEDIA_IMAGES"
Sh "am start -W -n $Package/$cls.MainActivity" | Out-Null

# 6. Wallpapers into the TV's Pictures/TV_Wallpapers.
Step 'Adding wallpapers'
$pics = if ($Wallpapers) { Get-ChildItem $Wallpapers -File -Recurse | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' } }
        else { Get-ChildItem (Join-Path $here 'wallpapers') -File | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' } }
Sh 'mkdir -p /sdcard/Pictures/TV_Wallpapers'
foreach ($p in $pics) {
    Push $p.FullName "/sdcard/Pictures/TV_Wallpapers/$($p.Name)"
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
Push $tmp /data/local/tmp/dx.json
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
