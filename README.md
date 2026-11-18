# DisplayX

A wallpaper-first Home for Android TV and Google TV, built on the
[cleanyourtv](https://github.com/Gathin23/cleanyourtv) launcher (MIT). It's light enough for 2 GB TVs; Home measured
43 MB on a 1.8 GB TV.

- **Frosted glass clock:** the wallpaper shows through the digits. They stay readable over dark, bright and busy
  pictures.
- **Moving glass focus:** a glass outline that springs between tiles as you move.
- **Wallpaper mode:** after 5 seconds idle, only the wallpaper, clock and greeting stay; any button brings Home back.
- **Rows:** Continue watching (from your apps' own progress) and Your apps, each fading when you're not in it.
- **Balanced slideshow:** each picture is shown about equally often, never twice in a row.
- **Wallpapers fit:** they're stretched to fit, so nothing is cropped.

## Build and install

1. Clone cleanyourtv at commit `718f98c9` and apply the change: `git apply source/displayx.patch`.
2. Build with its own app ID, so it installs beside the cleanyourtv launcher instead of over it (JDK 17, Android SDK 34):
   `./gradlew -p launcher assembleRelease -PlauncherApplicationId=tv.displayx.home -PlauncherAppLabel=DisplayX`.
   Copy `launcher/app/build/outputs/apk/release/app-release.apk` to `apk/displayx.apk`.
3. On the TV, turn on Developer options > Wireless debugging and pair once with `adb pair`.
4. Run `powershell -ExecutionPolicy Bypass -File install.ps1 -Serial <tv ip>:<port> -Package tv.displayx.home`.
   It leaves every other accessibility service (TalkBack and others) as it was.
5. Put your pictures in the TV's `Pictures/TV_Wallpapers` folder.
6. Replace `tv.displayx.home` with your own ID if you publish your own fork.
7. To change the look, edit `theme/config.json`. The keys are listed in cleanyourtv's `themes/README.md`, plus
   `glass_clock`, `liquid_glass`, `wallpaper_mode`, `wallpaper_fit`, `tile_glow_ring`, `keep_location_off`,
   `weather_location` and `settings_key_clear_task`.

## Permissions

Read these before you install.

| Permission | Why |
|---|---|
| `READ_MEDIA_IMAGES` | Your wallpapers, from `Pictures/TV_Wallpapers` |
| `READ_TV_LISTINGS` | Continue watching |
| `INTERNET` | Two uses. 1) Continue watching posters: the image addresses your streaming apps publish to Android's TV listings, fetched over HTTPS (capped in size). 2) Weather, only if you set `"weather_location": "lat,lon"` in the theme: open-meteo.com once an hour for that place, rounded to about 10 km. Without a location the greeting follows the time of day. Nothing else goes online |
| Accessibility service (`HomeKeyService`) | Only on TVs whose Home button skips the chosen Home |

## Credit and licence

Built on cleanyourtv by Gathin23 and its contributors (MIT). Inter font: SIL Open Font License (`INTER-FONT-OFL.txt`).
