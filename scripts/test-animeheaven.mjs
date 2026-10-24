// Usage: node scripts/test-animeheaven.mjs   (hits the live site)
import { readFileSync } from "node:fs";
import assert from "node:assert";

const src = readFileSync(new URL("../utils/scripts/animeheaven.js", import.meta.url), "utf8").replace(".pragma library", "");
const AH = new Function(`${src}; return { countdownMs, parseSchedule, parseEpisodes, parseSearch, findShow, searchUrl, decode, today, episodesStale, scheduleStale };`)();
const asrc = readFileSync(new URL("../utils/scripts/anime.js", import.meta.url), "utf8").replace(".pragma library", "");
const A = new Function(`${asrc}; return { b64, parseZoko, zokoUrl, afterPlay, mergeAnilist, fromMedia, watched, searchQuery, anilistApi };`)();

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

// 80% rule: resume point below it, next episode past it, gone after the last one, rewatches ignored
const w = { id: "1", ep: 3, pos: 0, dur: 0, at: 0, total: 12 };
assert.deepEqual(A.afterPlay(w, 3, 600, 1400, 9), { ...w, pos: 600, dur: 1400, at: 9 });
assert.deepEqual(A.afterPlay(w, 3, 1150, 1400, 9), { ...w, ep: 4, at: 9 });
assert.equal(A.afterPlay({ ...w, ep: 12 }, 12, 1300, 1400, 9), null);
assert.equal(A.afterPlay(w, 2, 1300, 1400, 9), w);
assert.equal(A.afterPlay({ ...w, total: 0 }, 3, 1300, 1400, 9).ep, 4);
// AniList list only wins when further along
const media = p => ({ id: 1, idMal: 5, title: { english: "X", romaji: "Ekusu" }, coverImage: { large: "i" }, episodes: 12, status: "RELEASING", nextAiringEpisode: { episode: 6, airingAt: 100 }, mediaListEntry: p === null ? null : { progress: p, updatedAt: 1 } });
assert.equal(A.fromMedia(media(0)).aired, 5);
assert.equal(A.mergeAnilist({ 1: w }, [media(1)], false)[1].ep, 3);
assert.equal(A.mergeAnilist({ 1: w }, [media(4)], false)[1].ep, 5);
assert.equal(A.mergeAnilist({ 1: w }, [media(null)], false)[1].ep, 3);
assert.equal(A.mergeAnilist({}, [media(29)], true)[1].ep, 30);
assert.deepEqual(Object.keys(A.mergeAnilist({ 1: w, 2: { ...w, id: "2" } }, [media(1)], true)), ["1"]); // removed on AniList
assert.equal(A.b64(btoa("hi\xff!")), "hi\xff!");
assert.equal(AH.findShow([{ id: "a", title: "Blue Box" }, { id: "b", title: "Blue Box Season 2" }], ["Blue Box Season 2"]), "b");
assert.equal(AH.findShow([{ id: "c", title: "The Apothecary Diaries 3rd Season" }], ["The Apothecary Diaries Season 3"]), "c");
assert.equal(AH.findShow([{ id: "a", title: "Blue Box" }], ["Blue Lock"]), "");

const get = async u => (await fetch(u, { headers: { "User-Agent": "Mozilla/5.0" } })).text();
const shows = AH.parseSchedule(await get("https://animeheaven.me/"), Date.now());
assert(shows.length > 10, `only ${shows.length} airing shows parsed`);
assert(shows.every(s => s.id && s.title && s.nextEp > 0), "show missing fields");
assert(shows.some(s => s.airAt > Date.now()), "no countdowns parsed");

const eps = AH.parseEpisodes(await get(`https://animeheaven.me/anime.php?${shows[0].id}`));
assert(eps.length > 0 && /^[0-9a-f]{32}$/.test(eps[0].key), "no episodes parsed");

const found = AH.parseSearch(await get(AH.searchUrl("blue box")));
assert(found.some(r => r.title === "Blue Box"), "AnimeHeaven search parse failed");

// AniList search -> MAL id -> ZokoAnime stream (Frieren, ep 1)
const al = await (await fetch(A.anilistApi, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ query: A.searchQuery, variables: { q: "frieren" } }) })).json();
const frieren = A.fromMedia(al.data.Page.media[0]);
assert.equal(frieren.idMal, 52991);
const stream = A.parseZoko(await get(A.zokoUrl(frieren.idMal, 1)));
assert(stream && /\.m3u8/.test(stream.src), "ZokoAnime stream not found");

console.log(`ok: ${shows.length} airing, "${shows[0].title}" has ${eps.length} eps, latest ${eps[0].ep}; zoko ${stream.src.slice(0, 40)}…`);
