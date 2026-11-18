# AGENTS.md

For coding agents (Claude Code, Codex, Gemini CLI, Cursor and others) setting up this Home on someone's TV. People
should start with [README.md](README.md).

## What this is, and when it fits

A Home screen for Android TV and Google TV, built on the [cleanyourtv](https://github.com/Gathin23/cleanyourtv)
launcher. It has its own app ID, so it installs beside the cleanyourtv launcher, never over it.

It fits when the person wants:
- a wallpaper-first, Google TV-style Home (Continue watching, an apps row, a big clock);
- a light Home for a 2 GB TV;
- no network use by default, beyond Continue watching posters from the streaming apps' own image addresses.

For a plain, minimal Home, cleanyourtv's own launcher is the better choice.

## Tested on

| TV | Android | RAM | Home memory (PSS) |
|---|---|---|---|
| TCL 55" Google TV (MediaTek) | 14 | 2.4 GB | 63–84 MB, all effects on |
| Haier Google TV (MediaTek) | 14 | 1.8 GB | 43 MB plain tiles; 68 MB with a wallpaper slideshow |
| Google TV 14 emulator (x86, fresh, no Google account) | 14 | 2 GB | 62–65 MB through 10,000 random key presses, no crash |

Untested elsewhere. Say so to the person, and screenshot after installing (below).

## Steps

1. **Debloat first:** follow cleanyourtv's `PROMPT.md` and its safety rules for disabling apps. This repo changes
   nothing about that, and adds no extra disabling steps.
2. **Build:** apply `source/displayx.patch` to cleanyourtv commit `718f98c9`. Then build with
   `./gradlew -p launcher testReleaseUnitTest assembleRelease -PlauncherApplicationId=<app id>`. The tests must pass.
3. **Install:** `install.ps1 -Serial <tv ip>:<port> -Package <app id>`. It grants two permissions, pushes
   `theme/config.json`, makes this Home the default, and keeps every other accessibility service on the list. On
   Google TV it adds `stock_home_redirect`, because Google TV keeps its own home for the Home button even when another
   app holds the Home role.
4. **Check:** confirm it's in front with `dumpsys activity activities | grep topResumedActivity`. Take a screenshot.
   Ask the person to press Home and the gear on the real remote: an injected key is not proof.
5. **Close ADB:** finish as cleanyourtv's `PROMPT.md` says.

## Settings an agent may change

Change these in `theme/config.json`, then run the installer again:

| Key | Default | What it does |
|---|---|---|
| `glass_clock` | true | Frosted glass clock. It keeps a contrast floor and adds a dark halo over busy pictures |
| `liquid_glass` | true | Glass top bar and the moving glass focus |
| `wallpaper_mode` | true | After 5 s idle only the wallpaper, clock and greeting stay; the next key only wakes |
| `wallpaper_fit` | `"stretch"` | `"stretch"` fills the screen; anything else crops |
| `tile_glow_ring` | false | A white ring off the focused tile, besides its glow |
| `weather_location` | unset | `"lat,lon"`: weather in the greeting from open-meteo.com. Unset means no network at all |
| `settings_key_clear_task` | false | On MediaTek TVs, Back from Settings returns Home |
| `greeting_name` | unset | A name in the greeting. Ask the person; never guess |

The rest of the keys are cleanyourtv's (`themes/README.md` there).

## Don't

- **Don't install over the cleanyourtv launcher:** build with your own `-PlauncherApplicationId`.
- **Don't set `weather_location` or `greeting_name` without asking.** They're the owner's choice.
- **Don't ship pictures you have no right to share.** Wallpapers go in the TV's `Pictures/TV_Wallpapers`.
- **Don't change system settings** (Location, DNS, animations) from here. `keep_location_off` is an owner opt-in.
