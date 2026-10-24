# NoShell (caelestia-shell fork, branch anime-calendar)

Fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) (merged up to upstream main 2e1c51fa,
2026-10-24), branch `anime-calendar`.
Published at https://github.com/NoAppsStudioNo/NoShell (remotes: `origin` = NoShell, `upstream` = caelestia-dots/shell).
Friends install/update with `install.sh` (clones into `~/.config/quickshell/caelestia`). It runs live as the user's shell: `~/.config/quickshell/caelestia` is a symlink to this repo.

## Rules

- Prefer QML/JS. `plugin/` (C++) is compiled into the `noshell` pacman package (`packaging/PKGBUILD`, replaces
  `caelestia-shell`), which install.sh rebuilds whenever the last commit touching `plugin`, `extras` or `CMakeLists.txt`
  changes, so a C++ change costs everyone a ~1 min rebuild. Fork settings live in the fork's services, not `Config.*`.
- Syncing upstream: `git fetch upstream && git merge upstream/main`, then grep the fork's files for QML types upstream
  removed/renamed, build (`cmake -B <dir> -G Ninja && cmake --build <dir> && DESTDIR=<dir>/root cmake --install <dir>`)
  and run `QML_IMPORT_PATH=<dir>/root/usr/lib/qt6/qml qs -p <checkout>` to test against the new plugin before installing.
- Match upstream style (Tokens/Colours/StyledText/IconButton, `Tr.tr` for strings).

## Anime calendar feature

- `utils/scripts/animeheaven.js`: scraper + scheduling logic (pure JS). Test: `node scripts/test-animeheaven.mjs` (hits live site).
- `services/AnimeHeaven.qml`: singleton; polling, cache, tracked shows, settings, download (curl → mpv via `execDetached`).
- `modules/background/AnimeCalendar.qml`: the desktop widget (today view + picker). Placed in `Background.qml`.
- `modules/background/ContinueWatching.qml`: widget above the calendar (same loader/column). Shows one show
  (`AnimeHeaven.current`: picked via `settings.current`, else most recent); the library button lists `continueList`
  and searches AniList, and the background window takes keyboard focus only while it's open. Logged in, the library
  mirrors the AniList CURRENT/REPEATING list (adding a show adds it there; no removing in the widget). Rows are `AnimeShowRow.qml`, a separate file because inline components
  of a `ComponentBehavior: Bound` file can't be used from other files.
- `utils/scripts/anime.js`: AniList queries, ZokoAnime stream parsing, 80%-watched rule (`afterPlay`). Same test script.
- `utils/scripts/anime-progress.lua`: mpv hook writing `{key,pos,dur}` to `~/.local/state/caelestia/anime-progress.json`
  on close; the service watches that file, resumes with `--start`, advances the episode past 80%.
- `modules/drawers/Regions.qml`: input-mask hole so the widget is clickable under the drawers' edge drag strip.
- `modules/nexus/pages/AnimeCalendarPage.qml`: settings page, registered in `PageRegistry.qml` and
  `PageCompRegistry.qml` (parallel arrays, keep the same index).
- State/cache: `~/.local/state/caelestia/anime.json`. Downloads: `~/Videos/Anime/<show>/`.

## Site facts (animeheaven.me)

- Homepage = schedule (`div.chart`), countdown text like "1 Day 2 Hours 3 Min" or "Episode Released"/"Finished airing".
- `anime.php?<id>` lists uploaded episodes as `gatea("<32-hex key>")` + episode number.
- Download: `https://ci.animeheaven.me/video.mp4?<key>&d` (no cookies needed).
- `search.php?s=<q>` lists shows as `similarname c'><a href='anime.php?<id>'`.
- Continue watching streams from ZokoAnime by MAL id (`zokoanime.video/stream/mal/<mal>/<ep>/sub`, config is
  base64(json XOR "otaku-embed-v1") in `window.__P`, HLS needs Referer `https://zokoanime.video/`), falling back to
  AnimeHeaven by title. AnimePahe and AllAnime are behind Cloudflare challenges, Anikoto needs an obfuscated `vrf`.
- AniList login: implicit grant, `utils/scripts/anilist-login.py` catches the redirect on http://127.0.0.1:8765/ and
  prints the token (stored in `settings.anilistToken`). Client: "NoShell", id `Anime.anilistClientId` (54762), registered on the owner's AniList account.
- Keep scraping light: schedule every 6h, show pages every 12h, 15 min only while an aired episode awaits upload.

## NoVolume volume wheel

- Replaces the right-edge OSD (volume/mic/brightness sliders) unless the `style` setting is 1 (Nexus > NoVolume > "Volume style"),
  which brings back upstream's `modules/osd/Content.qml` sliders and panel blob (`osdBg` in `ContentWindow.qml`, only visible
  then). `modules/osd/Wrapper.qml` hosts both; the wheel is
  `modules/osd/NoVolumeDial.qml`, a Canvas port of the half wheel in the NoVolume Android app
  (`~/Documents/projects/NoVolume`, `VolumeDialView.kt`). It draws in the app's units (phone px at 3x), so its
  constants carry over; `u` converts to shell px.
  Canvas is software-painted: never repaint per frame. Canvases repaint only when their settings key changes;
  volume/animations move GPU items (marker ring `rotation`, `Shape` arcs, `Text` readout, press `Scale`).
- Shell theme + no background override: the wheel's face is a `BlobRect` (`osdBg` in `ContentWindow.qml`, shaped from
  `Wrapper.faceLeft/faceHalf`) so it is the border's exact colour and bulges out of it; the dial's own face canvas is hidden then
  (`blobFace`). The wheel sits `edgeInset` px in from the screen edge. A `BlobRect` ignores `visible`: collapse it to size 0.
- Settings: `services/NoVolume.qml` (`~/.local/state/caelestia/novolume.json`, option names follow the app), page
  `modules/nexus/pages/NoVolumePage.qml`. Colours are a theme (shell/dark/light) plus per-element overrides; a value
  is `#rrggbb`/`#aarrggbb` or a `Colours.palette` name so it follows the wallpaper.
- Fonts in `assets/novolume/`. Both NType files register as family "NType 82": regular is weight 100, Headline 400.

## Wallpaper Engine (live wallpapers)

- Rendered by waywallen (AppImage in `~/.local/opt/waywallen/`, plugin `org.waywallen.open-wallpaper-engine` in
  `~/.local/share/waywallen/plugins/`), both pinned and installed by `install.sh` only if Wallpaper Engine is in Steam.
- `utils/scripts/wallpaper-engine.py` (run without args for usage): `list` scans Workshop `project.json`s; `apply`/`stop`
  use DBus (`ApplyById`, `Quit`); account, QR login, Workshop search/subscribe and wallpaper properties use waywallen's
  control WebSocket (port = DBus property `WsPort`, protobuf `proto/control.proto` in waywallen's repo, field numbers
  pinned at v0.4.3) through a stdlib-only WebSocket + protobuf codec in the script. Without a live wallpaper the daemon
  runs `--no-display` (an idle one with a display covers the shell's wallpaper); `apply` restarts it with one.
  A fresh daemon has no Steam library, so starting it sends `LibraryAutoDetect`.
- Properties (`props`) only exist while the wallpaper is rendering; the schema's `value` ignores overrides.
- The utilities "play wallpaper" quick toggle (`PersistentState.wallpaperPlaying`) also pauses/resumes it (DBus
  `Pause`/`Resume`, and `apply --paused`).
- `services/WallpaperEngine.qml`: state in `~/.local/state/caelestia/wallpaper-engine.json`, reapplied on start.
  Applying also sets the preview as the normal wallpaper so the colour scheme follows. Picking a normal wallpaper stops it.
- `Background.qml` moves to the bottom layer and hides its wallpaper while one is on. The state must be read when the
  singleton is created: a layer change right after the window is created is lost (later changes work).
- UI: Nexus > Wallpaper & style > "Wallpaper Engine" button = sub-page 4 (`wallandstyle/WallpaperEnginePage.qml`: setup
  steps, Steam QR login, installed wallpapers, customise the live one), "Get more" = sub-page 5 (`WorkshopPage.qml`).

## Applying changes

File watching doesn't follow the symlink, so restart after edits and check the log:

```sh
qs kill -c caelestia; caelestia shell -d
qs log "$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)"
```

Pages that load lazily (e.g. Nexus pages) only show errors when opened; to compile-check without opening them,
copy the repo to a temp dir, replace `shell.qml` with one that `Qt.createComponent()`s the files and logs `errorString()`,
and run `qs -p <tmpdir>`.
