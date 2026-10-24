pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils
import "../utils/scripts/animeheaven.js" as AH
import "../utils/scripts/anime.js" as Anime

// Tracks airing shows from animeheaven.me (calendar) and shows being watched (continue watching, synced with
// AniList). Settings, shows and a cache of scraped pages live in ~/.local/state/caelestia/anime.json so restarts
// don't refetch anything.
Singleton {
    id: root

    property var settings: ({})
    property var tracked: ({}) // id -> { title, image, watched, latest }
    property list<var> schedule: [] // every airing show on the site
    property real scheduleAt // when schedule was fetched
    property var episodes: ({}) // id -> [{ ep, key }] newest first
    property var episodesAt: ({}) // id -> when episodes were fetched
    property var watching: ({}) // AniList id -> Anime.fromMedia fields + { ep (next to watch), pos/dur (resume point, s), at (last played), ah (AnimeHeaven id) }
    property real watchingAt // when watching was refreshed from AniList, not saved so every start syncs
    property list<var> searchResults: []
    property string anilistUser
    property string starting // AniList id of the show whose stream is being looked up
    property var downloads: ({}) // path -> true for every finished episode file in downloadDir
    property list<string> queued: [] // files being downloaded, rescanned until they show up
    property int pending
    property bool progressReady

    readonly property bool loading: pending > 0
    readonly property bool enabled: settings.enabled ?? true
    readonly property real opacity: settings.opacity ?? 0.85
    readonly property string downloadDir: `${Paths.videos}/Anime`
    readonly property string anilistToken: settings.anilistToken ?? ""
    readonly property bool loggingIn: loginProc.running
    readonly property string progressFile: `${Paths.state}/anime-progress.json`

    // The library, most recently played first. Leaves out shows with every episode watched (AniList may still say watching).
    readonly property list<var> continueList: Object.values(watching).filter(w => !(w.total && w.ep > w.total)).sort((a, b) => b.at - a.at)
    // The show in the widget: picked from the library, else the most recently played
    readonly property var current: continueList.find(w => w.id === settings.current) ?? continueList[0] ?? null

    // Re-evaluated every minute
    readonly property date now: Time.date

    // Tracked shows with an episode airing/aired today, by air time
    readonly property list<var> entries: Object.keys(tracked).map(id => {
        const t = tracked[id];
        const s = schedule.find(s => s.id === id);
        const eps = episodes[id] ?? [];
        const today = s ? AH.today(s, now.getTime()) : null;
        return {
            id,
            title: t.title,
            image: t.image,
            today,
            uploaded: eps[0]?.ep ?? -1,
            episode: eps.find(e => e.ep === today?.ep) ?? null, // today's episode once uploaded
            local: !!downloads[filePath(t.title, today?.ep)],
            aired: (today?.at ?? Infinity) <= now.getTime(),
            watched: (t.watched ?? -1) >= (today?.ep ?? Infinity)
        };
    }).filter(e => e.today).sort((a, b) => a.today.at - b.today.at)

    function isTracked(id: string): bool {
        return tracked[id] !== undefined;
    }

    function setSetting(key: string, value: var): void {
        const s = Object.assign({}, settings);
        s[key] = value;
        settings = s;
        save();
    }

    function toggle(show: var): void {
        const t = Object.assign({}, tracked);
        if (t[show.id]) {
            delete t[show.id];
        } else {
            t[show.id] = {
                title: show.title,
                image: show.image
            };
            fetchEpisodes(show.id);
        }
        tracked = t;
        save();
    }

    function filePath(title: string, ep: real): string {
        const name = title.replace(/[\/\\:*?"<>|]/g, "-");
        return `${downloadDir}/${name}/${name} - ${String(ep).padStart(2, "0")}.mp4`;
    }

    // Downloaded copy of a watching entry's episode, or "". Folders are named after the AnimeHeaven title, so
    // try the tracked title linked to this show as well as the AniList ones.
    function localFile(w: var, ep: real): string {
        const linked = Object.values(tracked).filter(t => t.anilist === w.id).map(t => t.title);
        return linked.concat(w.titles ?? [w.title]).map(t => filePath(t, ep)).find(f => downloads[f]) ?? "";
    }

    function scan(): void {
        scanProc.running = true;
    }

    // The calendar button: play/download from AnimeHeaven, else stream (an aired episode it doesn't have yet)
    function playEntry(e: var): void {
        if (e.episode || e.local)
            play(e.id, e.episode ?? e.today);
        else
            linkAnilist(e.id, al => al && watch(al, e.today.ep));
    }

    function play(id: string, ep: var): void {
        const t = tracked[id];
        const file = filePath(t.title, ep.ep);
        const label = `${t.title} episode ${ep.ep}`;
        if (!downloads[file])
            queued = queued.concat(file);

        linkAnilist(id, al => {
            const w = watching[al];
            // Detached so downloads survive shell reloads. Resumes partial downloads, skips finished ones.
            Quickshell.execDetached(["sh", "-c", `f="$1" url="$2" label="$3"; shift 3
[ -f "$f" ] || { notify-send -a AnimeHeaven "Downloading" "$label"; mkdir -p "\${f%/*}" && curl -fsL -C - -A Mozilla/5.0 -o "$f.part" "$url" && mv "$f.part" "$f"; } \
&& exec mpv "$@" "$f" || notify-send -u critical -a AnimeHeaven "Download failed" "$label"`, "sh", file, AH.downloadUrl(ep.key), label, ...mpvArgs(label, `${al}:${id}:${ep.ep}`, w?.ep === ep.ep ? w.pos : 0)]);
        });
    }

    function openPage(id: string): void {
        Qt.openUrlExternally(AH.animeUrl(id));
    }

    function update(id: string, props: var): void {
        const t = Object.assign({}, tracked);
        t[id] = Object.assign({}, t[id], props);
        tracked = t;
        save();
    }

    // Plays an episode of a watching entry (default: the next one): the downloaded file if there is one, else
    // streams from ZokoAnime (by MAL id) with AnimeHeaven as the fallback
    function watch(id: string, episode: var): void {
        const w = watching[id];
        const ep = episode ?? w.ep;
        const file = localFile(w, ep);
        if (file)
            return launch(w, ep, file, []);
        starting = id;
        const fail = () => {
            starting = "";
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "AnimeHeaven", "No source found", `${w.title} episode ${ep}`]);
        };
        const fromAh = () => findAh(w, ah => ahStream(ah, ep, url => launch(w, ep, url, []), fail), fail);
        if (!w.idMal)
            return fromAh();
        Requests.get(Anime.zokoUrl(w.idMal, ep), html => {
            const s = Anime.parseZoko(html);
            if (!s)
                return fromAh();
            launch(w, ep, s.src, [`--referrer=${Anime.zokoReferer}`].concat(s.sub ? [`--sub-file=${s.sub}`] : []));
        }, fromAh, {
            "User-Agent": "Mozilla/5.0"
        });
    }

    function launch(entry: var, ep: real, url: string, extra: var): void {
        const w = watching[entry.id] ?? entry; // findAh may have just added the AnimeHeaven id
        starting = "";
        Quickshell.execDetached(["mpv", ...mpvArgs(`${w.title} - Episode ${ep}`, `${w.id}:${w.ah ?? ""}:${ep}`, ep === w.ep ? w.pos : 0), ...extra, url]);
    }

    // Starts a few seconds before the resume point, and loads the Lua hook that reports where playback stopped
    // (handled by handleProgress). key = "<AniList id>:<AnimeHeaven id>:<episode>", either id may be empty.
    function mpvArgs(title: string, key: string, start: real): var {
        return [`--force-media-title=${title}`, `--start=${Math.max(0, start - 5)}`, `--script=${Quickshell.shellPath("utils/scripts/anime-progress.lua")}`, `--script-opts=anime-progress-file=${progressFile},anime-progress-key=${key}`];
    }

    function handleProgress(report: var): void {
        const [al, ah, epStr] = report.key.split(":");
        const ep = parseFloat(epStr);
        const done = Anime.watched(report.pos, report.dur);
        const w = watching[al];

        if (done && w && ep >= w.ep && anilistToken)
            anilist(Anime.saveMutation, {
                id: parseInt(al),
                p: Math.floor(ep),
                s: w.total && ep >= w.total ? "COMPLETED" : "CURRENT"
            }, () => {});
        if (w)
            setWatching(al, Anime.afterPlay(w, ep, report.pos, report.dur, Date.now()));
        if (done && tracked[ah] && ep > (tracked[ah].watched ?? -1))
            update(ah, {
                watched: ep
            });
    }

    // AnimeHeaven id of a watching entry, found by title once and remembered
    function findAh(w: var, onFound: var, onFail: var): void {
        if (w.ah)
            return onFound(w.ah);
        Requests.get(AH.searchUrl(w.title), html => {
            const ah = AH.findShow(AH.parseSearch(html), w.titles);
            if (!ah)
                return onFail();
            setWatching(w.id, Object.assign({}, watching[w.id], {
                ah
            }));
            onFound(ah);
        }, onFail);
    }

    function ahStream(ah: string, ep: real, onUrl: var, onFail: var): void {
        const cached = episodes[ah]?.find(e => e.ep === ep);
        if (cached)
            return onUrl(AH.downloadUrl(cached.key));
        Requests.get(AH.animeUrl(ah), html => {
            const e = AH.parseEpisodes(html).find(e => e.ep === ep);
            e ? onUrl(AH.downloadUrl(e.key)) : onFail();
        }, onFail);
    }

    // AniList id of a calendar show, found by title once and remembered. Also adds it to continue watching
    // (again, if it was removed on AniList since).
    function linkAnilist(ah: string, onDone: var): void {
        const t = tracked[ah];
        if (t.anilist && watching[t.anilist])
            return onDone(t.anilist);
        anilist(Anime.searchQuery, {
            q: t.title
        }, data => {
            const m = data.Page.media.find(m => String(m.id) === t.anilist) ?? data.Page.media[0];
            if (!m)
                return onDone("");
            const show = Anime.fromMedia(m);
            update(ah, {
                anilist: show.id
            });
            add(show, Math.max(show.progress, t.watched ?? 0) + 1);
            onDone(show.id);
        }, () => onDone(""));
    }

    function isWatching(id: string): bool {
        return watching[id] !== undefined;
    }

    function select(id: string): void {
        setSetting("current", id);
    }

    // Adds a show to the library, and to the AniList watching list when logged in (the library mirrors that list,
    // see refreshWatching), then shows it in the widget
    function add(show: var, ep: real): void {
        if (!watching[show.id])
            setWatching(show.id, Object.assign({}, show, {
                ep,
                pos: 0,
                dur: 0,
                at: Date.now()
            }));
        select(show.id);
        if (anilistToken)
            anilist(Anime.saveMutation, {
                id: parseInt(show.id),
                p: Math.floor(Math.max(watching[show.id].ep - 1, show.progress)),
                s: "CURRENT"
            }, () => {});
    }

    function setWatching(id: string, entry: var): void {
        const w = Object.assign({}, watching);
        if (entry)
            w[id] = entry;
        else
            delete w[id];
        watching = w;
        save();
    }

    function search(text: string): void {
        if (!text.trim())
            return searchResults = [];
        anilist(Anime.searchQuery, {
            q: text
        }, data => searchResults = data.Page.media.map(Anime.fromMedia));
    }

    // Opens AniList in the browser; anilist-login.py catches the redirect and prints the token
    function login(): void {
        loginProc.running = true;
    }

    function setAnilistToken(token: string): void {
        anilistUser = "";
        setSetting("anilistToken", token.trim());
        refreshWatching();
    }

    // Logged in: the library becomes the AniList watching list. Then refreshes airing info for every show.
    function refreshWatching(): void {
        watchingAt = Date.now();
        const refreshMedia = () => {
            const ids = Object.keys(watching).map(Number);
            if (ids.length)
                anilist(Anime.mediaQuery, {
                    ids
                }, data => {
                    watching = Anime.mergeAnilist(watching, data.Page.media, false);
                    save();
                });
        };
        if (!anilistToken)
            return refreshMedia();
        anilist(Anime.viewerQuery, {}, data => {
            anilistUser = data.Viewer.name;
            anilist(Anime.listQuery, {
                u: data.Viewer.id
            }, data => {
                const media = data.MediaListCollection.lists.reduce((all, l) => all.concat(l.entries.map(e => e.media)), []);
                watching = Anime.mergeAnilist(watching, media, true);
                refreshMedia();
            });
        });
    }

    // AniList GraphQL. Requests.get can't POST, so this uses XMLHttpRequest.
    function anilist(query: string, variables: var, onDone: var, onFail: var): void {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", Anime.anilistApi);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Accept", "application/json");
        if (anilistToken)
            xhr.setRequestHeader("Authorization", `Bearer ${anilistToken}`);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let res = null;
            try {
                res = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (res?.data && !res.errors)
                return onDone(res.data);
            console.warn("AnimeHeaven: AniList request failed:", xhr.status, xhr.responseText.slice(0, 300));
            onFail?.();
        };
        xhr.send(JSON.stringify({
            query,
            variables
        }));
    }

    // Only fetches what's stale (see AH.*Stale), unless forced by the refresh button
    function poll(force: bool): void {
        const n = Date.now();
        scan();
        if (force || AH.scheduleStale(watchingAt, n))
            refreshWatching();
        if (force || AH.scheduleStale(scheduleAt, n))
            fetchSchedule();
        for (const id of Object.keys(tracked)) {
            const s = schedule.find(s => s.id === id);
            if (force || AH.episodesStale(episodesAt[id], episodes[id]?.[0]?.ep, s ? AH.today(s, n) : null, n))
                fetchEpisodes(id);
        }
    }

    function fetchSchedule(): void {
        pending++;
        Requests.get("https://animeheaven.me/", text => {
            pending--;
            schedule = AH.parseSchedule(text, Date.now());
            scheduleAt = Date.now();
            save();
        }, err => {
            pending--;
            console.warn("AnimeHeaven: schedule fetch failed:", err);
        });
    }

    function fetchEpisodes(id: string): void {
        pending++;
        Requests.get(AH.animeUrl(id), text => {
            pending--;
            const eps = AH.parseEpisodes(text);
            const e = Object.assign({}, episodes);
            e[id] = eps;
            episodes = e;
            const at = Object.assign({}, episodesAt);
            at[id] = Date.now();
            episodesAt = at;

            const t = tracked[id];
            const latest = eps[0]?.ep;
            if (!t || latest === undefined || latest === t.latest)
                return save();
            if (t.latest !== undefined && latest > t.latest)
                Quickshell.execDetached(["notify-send", "-a", "AnimeHeaven", "New episode out", `${t.title} episode ${latest}`]);
            // Newly tracked shows start with only the latest episode marked as new
            update(id, {
                latest,
                watched: t.watched ?? latest - 1
            });
        }, err => {
            pending--;
            console.warn("AnimeHeaven: episode fetch failed for", id, err);
        });
    }

    function save(): void {
        storage.setText(JSON.stringify({
            settings,
            tracked,
            watching,
            cache: {
                schedule,
                scheduleAt,
                episodes,
                episodesAt
            }
        }));
    }

    // Lists finished downloads (.part files don't match)
    Process {
        id: scanProc

        command: ["find", root.downloadDir, "-name", "*.mp4", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {};
                for (const f of text.split("\n"))
                    if (f)
                        d[f] = true;
                root.downloads = d;
                root.queued = root.queued.filter(f => !d[f]);
            }
        }
    }

    // ponytail: a download that fails stays queued (a find every 3s) until the shell restarts
    Timer {
        interval: 3000
        running: root.queued.length > 0
        repeat: true
        onTriggered: root.scan()
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.poll(false)
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.state}/anime.json`
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.settings = data.settings ?? {};
                root.tracked = data.tracked ?? {};
                root.watching = data.watching ?? {};
                root.schedule = data.cache?.schedule ?? [];
                root.scheduleAt = data.cache?.scheduleAt ?? 0;
                root.episodes = data.cache?.episodes ?? {};
                root.episodesAt = data.cache?.episodesAt ?? {};
            } catch (e) {
                console.warn("AnimeHeaven: bad state file:", e);
            }
            touchProgress.running = true;
            root.poll(false);
        }
        onLoadFailed: {
            touchProgress.running = true;
            root.poll(false);
        }
    }

    Process {
        id: loginProc

        command: ["python3", Quickshell.shellPath("utils/scripts/anilist-login.py"), Anime.authUrl(Anime.anilistClientId)]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.setAnilistToken(text);
            }
        }
    }

    // FileView only watches files that exist when it first loads them
    Process {
        id: touchProgress

        command: ["touch", root.progressFile]
        onExited: root.progressReady = true
    }

    // Written by utils/scripts/anime-progress.lua when mpv closes an episode. Read after the state file so a
    // report written while the shell was down still applies; rereading an old one changes nothing (Anime.afterPlay).
    FileView {
        id: progress

        printErrors: false
        path: root.progressReady ? root.progressFile : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let report = null;
            try {
                report = JSON.parse(text());
            } catch (e) {}
            if (report?.key)
                root.handleProgress(report);
        }
    }
}
