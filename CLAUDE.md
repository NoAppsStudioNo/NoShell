# NoShell (caelestia-shell fork, branch anime-calendar)

Fork of [caelestia-dots/shell](https://github.com/caelestia-dots/shell) at tag v2.5.0, branch `anime-calendar`.
Published at https://github.com/NoAppsStudioNo/NoShell (remotes: `origin` = NoShell, `upstream` = caelestia-dots/shell).
Friends install/update with `install.sh` (clones into `~/.config/quickshell/caelestia`). It runs live as the user's shell: `~/.config/quickshell/caelestia` is a symlink to this repo.

## Rules

- QML/JS only. Never change `plugin/` (C++); it is not rebuilt, the shell uses the compiled plugin from the
  `caelestia-shell` 2.5.0 AUR package. So no new `Config.*` options; fork settings live in `AnimeHeaven.settings`.
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

## Applying changes

File watching doesn't follow the symlink, so restart after edits and check the log:

```sh
qs kill -c caelestia; caelestia shell -d
qs log "$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1)"
```

Pages that load lazily (e.g. Nexus pages) only show errors when opened; to compile-check without opening them,
copy the repo to a temp dir, replace `shell.qml` with one that `Qt.createComponent()`s the files and logs `errorString()`,
and run `qs -p <tmpdir>`.
