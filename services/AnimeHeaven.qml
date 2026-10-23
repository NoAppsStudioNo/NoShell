pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.utils
import "../utils/scripts/animeheaven.js" as AH

// Tracks airing shows from animeheaven.me. Settings, tracked shows and a cache of scraped pages
// live in ~/.local/state/caelestia/anime.json so restarts don't refetch anything.
Singleton {
    id: root

    property var settings: ({})
    property var tracked: ({}) // id -> { title, image, watched, latest }
    property list<var> schedule: [] // every airing show on the site
    property real scheduleAt // when schedule was fetched
    property var episodes: ({}) // id -> [{ ep, key }] newest first
    property var episodesAt: ({}) // id -> when episodes were fetched
    property int pending

    readonly property bool loading: pending > 0
    readonly property bool enabled: settings.enabled ?? true
    readonly property real opacity: settings.opacity ?? 0.85
    readonly property string downloadDir: `${Paths.videos}/Anime`

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

    function play(id: string, ep: var): void {
        const t = tracked[id];
        const name = t.title.replace(/[\/\\:*?"<>|]/g, "-");
        const file = `${downloadDir}/${name}/${name} - ${String(ep.ep).padStart(2, "0")}.mp4`;
        const label = `${t.title} episode ${ep.ep}`;

        // Detached so downloads survive shell reloads. Resumes partial downloads, skips finished ones.
        Quickshell.execDetached(["sh", "-c", `f="$1"
[ -f "$f" ] || { notify-send -a AnimeHeaven "Downloading" "$3"; mkdir -p "\${f%/*}" && curl -fsL -C - -A Mozilla/5.0 -o "$f.part" "$2" && mv "$f.part" "$f"; } \
&& exec mpv "$f" || notify-send -u critical -a AnimeHeaven "Download failed" "$3"`, "sh", file, AH.downloadUrl(ep.key), label]);

        if (ep.ep > (t.watched ?? -1))
            update(id, {
                watched: ep.ep
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

    // Only fetches what's stale (see AH.*Stale), unless forced by the refresh button
    function poll(force: bool): void {
        const n = Date.now();
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
            cache: {
                schedule,
                scheduleAt,
                episodes,
                episodesAt
            }
        }));
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
                root.schedule = data.cache?.schedule ?? [];
                root.scheduleAt = data.cache?.scheduleAt ?? 0;
                root.episodes = data.cache?.episodes ?? {};
                root.episodesAt = data.cache?.episodesAt ?? {};
            } catch (e) {
                console.warn("AnimeHeaven: bad state file:", e);
            }
            root.poll(false);
        }
        onLoadFailed: root.poll(false)
    }
}
