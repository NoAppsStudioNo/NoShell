.pragma library

// Continue-watching helpers: AniList (catalog + sync), the ZokoAnime stream source and the watch progress rules.
// AnimeHeaven scraping lives in animeheaven.js.

const anilistApi = "https://graphql.anilist.co";
// "NoShell" AniList API client everyone logs in through (redirect URL http://127.0.0.1:8765/, see anilist-login.py)
const anilistClientId = "54762";
const zokoReferer = "https://zokoanime.video/";

const mediaFields = "id idMal title { romaji english } synonyms coverImage { large } episodes status seasonYear nextAiringEpisode { episode airingAt } mediaListEntry { progress updatedAt }";
const searchQuery = `query ($q: String) { Page(perPage: 15) { media(search: $q, type: ANIME, sort: SEARCH_MATCH) { ${mediaFields} } } }`;
const mediaQuery = `query ($ids: [Int]) { Page(perPage: 50) { media(id_in: $ids) { ${mediaFields} } } }`;
const viewerQuery = "query { Viewer { id name } }";
const listQuery = `query ($u: Int) { MediaListCollection(userId: $u, type: ANIME, status_in: [CURRENT, REPEATING]) { lists { entries { media { ${mediaFields} } } } } }`;
const saveMutation = "mutation ($id: Int, $p: Int, $s: MediaListStatus) { SaveMediaListEntry(mediaId: $id, progress: $p, status: $s) { id } }";

// Past this much of an episode the rest is credits, so it counts as watched
const watchedFraction = 0.8;

function authUrl(clientId) {
    return `https://anilist.co/api/v2/oauth/authorize?client_id=${clientId}&response_type=token`;
}

function anilistPage(id) {
    return `https://anilist.co/anime/${id}`;
}

// AniList media -> the show fields a watching entry keeps (refreshed from AniList, unlike ep/pos)
function fromMedia(m) {
    const next = m.nextAiringEpisode;
    return {
        id: String(m.id),
        title: m.title.english || m.title.romaji,
        romaji: m.title.romaji,
        titles: [m.title.english, m.title.romaji].concat(m.synonyms ?? []).filter(Boolean),
        year: m.seasonYear ?? 0,
        progress: m.mediaListEntry?.progress ?? 0, // episodes watched on AniList, only when logged in
        image: m.coverImage.large,
        idMal: m.idMal ?? 0,
        total: m.episodes ?? 0,
        aired: m.status === "NOT_YET_RELEASED" ? 0 : next ? next.episode - 1 : m.episodes ?? 9999,
        airAt: next ? next.airingAt * 1000 : 0
    };
}

function watched(pos, dur) {
    return dur > 0 && pos / dur >= watchedFraction;
}

// Watching entry after mpv reports where episode `ep` stopped: the next episode once watched, else the resume
// point. Older episodes (rewatches) change nothing. null = that was the last episode.
function afterPlay(entry, ep, pos, dur, now) {
    if (ep < entry.ep)
        return entry;
    if (!watched(pos, dur))
        return Object.assign({}, entry, { ep, pos, dur, at: now });
    if (entry.total && ep >= entry.total)
        return null;
    return Object.assign({}, entry, { ep: ep + 1, pos: 0, dur: 0, at: now });
}

// Watching map with AniList data merged in (mediaListEntry is only set when logged in). AniList progress wins only
// when it is further along. With `list` (media = the user's AniList watching list) the result is exactly that list:
// shows missing from it were removed on AniList.
function mergeAnilist(watching, media, list) {
    const w = list ? {} : Object.assign({}, watching);
    for (const m of media) {
        const show = fromMedia(m);
        const cur = watching[show.id];
        const at = (m.mediaListEntry?.updatedAt ?? 0) * 1000;
        if (!cur)
            w[show.id] = Object.assign(show, { ep: show.progress + 1, pos: 0, dur: 0, at });
        else if (show.progress + 1 > cur.ep)
            w[show.id] = Object.assign({}, cur, show, { ep: show.progress + 1, pos: 0, dur: 0, at: Math.max(cur.at, at) });
        else
            w[show.id] = Object.assign({}, cur, show);
    }
    return w;
}

function zokoUrl(idMal, ep) {
    return `${zokoReferer}stream/mal/${idMal}/${ep}/sub`;
}

// ZokoAnime embed page -> { src (HLS playlist, needs zokoReferer), sub (vtt url or "") }, or null if the episode
// isn't there. The player config is base64(json XOR "otaku-embed-v1") in window.__P, same as ani-cli's provider.
function parseZoko(html) {
    const m = /window\.__P="([^"]*)"/.exec(html);
    if (!m)
        return null;
    const key = "otaku-embed-v1";
    const bytes = b64(m[1]);
    let json = "";
    for (let i = 0; i < bytes.length; i++)
        json += String.fromCharCode(bytes.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    try {
        const c = JSON.parse(json);
        if (!c.src)
            return null;
        return { src: c.src, sub: (c.subtitles ?? []).find(s => s.default)?.src ?? "" };
    } catch (e) {
        return null;
    }
}

// Base64 -> one char per byte (QML has no atob)
function b64(s) {
    const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let bits = 0, n = 0, out = "";
    for (const c of s) {
        const v = abc.indexOf(c);
        if (v < 0)
            continue;
        bits = (bits << 6) | v;
        n += 6;
        if (n >= 8) {
            n -= 8;
            out += String.fromCharCode((bits >> n) & 255);
            bits &= (1 << n) - 1;
        }
    }
    return out;
}
