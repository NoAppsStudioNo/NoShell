.pragma library

// Scrapers for https://animeheaven.me. The site has no API, so these parse its HTML.
// If the site changes its markup, this is the file to fix.

const base = "https://animeheaven.me";

function decode(s) {
    return s.replace(/&#0*39;/g, "'").replace(/&quot;/g, '"').replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").trim();
}

function match(re, s) {
    const m = re.exec(s);
    return m ? m[1] : "";
}

// "1 Day 2 Hours 3 Min" -> ms, or -1 if not a countdown
function countdownMs(s) {
    if (!/\d+ (Day|Hour|Min)/.test(s))
        return -1;
    const n = re => parseInt(match(re, s) || "0");
    return ((n(/(\d+) Days?/) * 24 + n(/(\d+) Hours?/)) * 60 + n(/(\d+) Min/)) * 60000;
}

// Homepage schedule -> [{ id, title, image, nextEp, airAt (ms epoch, 0 if unknown), status }], airing shows only
function parseSchedule(html, now) {
    const shows = [];
    for (const chunk of html.split("<div class='chart bc1'>").slice(1)) {
        const status = decode(match(/class='charttimer c2'>([^<]*)</, chunk));
        if (!status || status === "Finished airing")
            continue;
        const ms = countdownMs(status);
        shows.push({
            id: match(/anime\.php\?(\w+)/, chunk),
            title: decode(match(/class='charttitle c'>\s*<a[^>]*>([^<]*)</, chunk)),
            image: `${base}/image.php?${match(/image\.php\?(\w+)/, chunk)}`,
            nextEp: parseFloat(match(/class='chartep c2'>([^<]*)</, chunk)) || 0,
            airAt: ms < 0 ? 0 : now + ms,
            status: ms < 0 ? status : ""
        });
    }
    return shows.filter(s => s.id && s.title);
}

// anime.php page -> [{ ep, key }] newest first
function parseEpisodes(html) {
    const eps = [];
    const re = /gatea\(\s*"([0-9a-f]+)"\)[\s\S]*?watch2 bc '\s*>([^<]+)</g;
    let m;
    while ((m = re.exec(html)))
        eps.push({ key: m[1], ep: parseFloat(m[2]) });
    return eps.filter(e => !isNaN(e.ep)).sort((a, b) => b.ep - a.ep);
}

const minute = 60000;
const hour = 60 * minute;
const day = 24 * hour;

function sameDay(a, b) {
    return new Date(a).toDateString() === new Date(b).toDateString();
}

// The episode of a schedule entry that airs/aired today as { ep, at } (at = 0 if time unknown), or null
function today(show, now) {
    if (show.airAt && sameDay(show.airAt, now))
        return { ep: show.nextEp, at: show.airAt };
    if (show.airAt && sameDay(show.airAt - 7 * day, now)) // site already counts down to next week's episode
        return { ep: show.nextEp - 1, at: show.airAt - 7 * day };
    if (show.status === "Episode Released")
        return { ep: show.nextEp, at: 0 };
    return null;
}

// Whether a show's episode list needs refetching. Polls every 15 min only while today's episode
// has aired but isn't uploaded yet, otherwise twice a day.
function episodesStale(fetchedAt, latest, todayEp, now) {
    const waiting = todayEp && (latest ?? -1) < todayEp.ep && todayEp.at <= now && (todayEp.at === 0 || now - todayEp.at < day);
    return now - (fetchedAt || 0) > (waiting ? 15 * minute : 12 * hour);
}

function scheduleStale(fetchedAt, now) {
    return now - (fetchedAt || 0) > 6 * hour;
}

function animeUrl(id) {
    return `${base}/anime.php?${id}`;
}

function downloadUrl(key) {
    return `https://ci.animeheaven.me/video.mp4?${key}&d`;
}
