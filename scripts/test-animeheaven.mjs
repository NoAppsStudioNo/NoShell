// Usage: node scripts/test-animeheaven.mjs   (hits the live site)
import { readFileSync } from "node:fs";
import assert from "node:assert";

const src = readFileSync(new URL("../utils/scripts/animeheaven.js", import.meta.url), "utf8").replace(".pragma library", "");
const AH = new Function(`${src}; return { countdownMs, parseSchedule, parseEpisodes, decode, today, episodesStale, scheduleStale };`)();

const noon = new Date(2026, 9, 23, 12, 0).getTime();
const H = 3600000, D = 24 * H;
assert.deepEqual(AH.today({ airAt: noon + 6 * H, nextEp: 5 }, noon), { ep: 5, at: noon + 6 * H });
assert.deepEqual(AH.today({ airAt: noon + 7 * D - 2 * H, nextEp: 5 }, noon), { ep: 4, at: noon - 2 * H });
assert.deepEqual(AH.today({ airAt: 0, nextEp: 3, status: "Episode Released" }, noon), { ep: 3, at: 0 });
assert.equal(AH.today({ airAt: noon + 2 * D, nextEp: 5 }, noon), null);
assert.equal(AH.today({ airAt: 0, nextEp: 5, status: "Episode Delayed" }, noon), null);
// aired 2h ago, not uploaded: poll after 15 min; uploaded or not aired yet: wait 12h
const aired = { ep: 4, at: noon - 2 * H };
assert.equal(AH.episodesStale(noon - 20 * 60000, 3, aired, noon), true);
assert.equal(AH.episodesStale(noon - 10 * 60000, 3, aired, noon), false);
assert.equal(AH.episodesStale(noon - 2 * H, 4, aired, noon), false);
assert.equal(AH.episodesStale(noon - 2 * H, 3, { ep: 4, at: noon + H }, noon), false);
assert.equal(AH.episodesStale(noon - 13 * H, 4, null, noon), true);
assert.equal(AH.episodesStale(undefined, undefined, null, noon), true);
assert.equal(AH.scheduleStale(noon - 5 * H, noon), false);
assert.equal(AH.scheduleStale(noon - 7 * H, noon), true);

assert.equal(AH.countdownMs("1 Day 2 Hours 3 Min"), ((24 + 2) * 60 + 3) * 60000);
assert.equal(AH.countdownMs("8 Hours 52 Min"), (8 * 60 + 52) * 60000);
assert.equal(AH.countdownMs("Episode Released"), -1);
assert.equal(AH.decode("A Certain Dark Side&#039;s Item &amp; co"), "A Certain Dark Side's Item & co");

const get = async u => (await fetch(u, { headers: { "User-Agent": "Mozilla/5.0" } })).text();
const shows = AH.parseSchedule(await get("https://animeheaven.me/"), Date.now());
assert(shows.length > 10, `only ${shows.length} airing shows parsed`);
assert(shows.every(s => s.id && s.title && s.nextEp > 0), "show missing fields");
assert(shows.some(s => s.airAt > Date.now()), "no countdowns parsed");

const eps = AH.parseEpisodes(await get(`https://animeheaven.me/anime.php?${shows[0].id}`));
assert(eps.length > 0 && /^[0-9a-f]{32}$/.test(eps[0].key), "no episodes parsed");

console.log(`ok: ${shows.length} airing, "${shows[0].title}" has ${eps.length} eps, latest ${eps[0].ep}`);
