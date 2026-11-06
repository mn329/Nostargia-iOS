// Web版の JS を実行して、Swift 版が一致すべきゴールデンデータを書き出す。
// 使い方（Nostargia-iOS のルートで）: TZ=Asia/Tokyo node tools/golden/generate.mjs ../Nostargia
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';

if (Intl.DateTimeFormat().resolvedOptions().timeZone !== 'Asia/Tokyo') {
  throw new Error('TZ=Asia/Tokyo を付けて実行してください');
}

const webRepo = resolve(process.argv[2] ?? '../Nostargia');
const fixturesDir = resolve('Packages/NostargiaKit/Tests/NostargiaKitTests/Fixtures');
const resourcesDir = resolve('Packages/NostargiaKit/Sources/NostargiaKit/Resources');
mkdirSync(fixturesDir, { recursive: true });
mkdirSync(resourcesDir, { recursive: true });
rmSync(join(fixturesDir, '.gitkeep'), { force: true });
rmSync(join(resourcesDir, '.gitkeep'), { force: true });

const require = createRequire(join(webRepo, 'package.json'));
const THREE = require('three');

const { getFallbackAnalysis } = await import(pathToFileURL(join(webRepo, 'src/utils/fallbackAnalysis.js')));
const { CONSTELLATIONS } = await import(pathToFileURL(join(webRepo, 'src/data/constellationData.js')));

// export されていない関数を、ソースから波括弧の対応で切り出す
function extractFunctions(file, names) {
  const src = readFileSync(join(webRepo, file), 'utf8');
  return { src, code: names.map((name) => {
    const start = src.indexOf(`function ${name}(`);
    if (start < 0) throw new Error(`${file} に ${name} が見つかりません`);
    const open = src.indexOf('{', src.indexOf(')', start));
    let depth = 0;
    let i = open;
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++;
      else if (src[i] === '}' && --depth === 0) break;
    }
    return src.slice(start, i + 1);
  }).join('\n') };
}

const star = extractFunctions('src/utils/starDataMaker.js', ['hashCode', 'generateMoodColor']);
const { hashCode, generateMoodColor } =
  new Function('THREE', `${star.code}\nreturn { hashCode, generateMoodColor };`)(THREE);

const time = extractFunctions('src/utils/appTime.js', ['getDiaryCycleStart', 'getDiaryCycleEnd']);
if (!time.src.includes('const RESET_HOUR = 6;')) throw new Error('RESET_HOUR が 6 ではありません');
const { getDiaryCycleStart, getDiaryCycleEnd } =
  new Function('RESET_HOUR', `${time.code}\nreturn { getDiaryCycleStart, getDiaryCycleEnd };`)(6);

// 再現できる疑似乱数（線形合同法）
let seed = 20261106;
const rand = () => {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return seed / 4294967296;
};

const KEYS = ['emotional', 'motivation', 'social', 'physical', 'fulfillment'];
const BOUNDARY = [0, 1, 33, 34, 50, 66, 67, 99, 100];
const moodOf = (f) => Object.fromEntries(KEYS.map((k) => [k, f(k)]));

const moods = [];
for (const v of BOUNDARY) moods.push(moodOf(() => v));
for (const k of KEYS) for (const v of BOUNDARY) moods.push({ ...moodOf(() => 50), [k]: v });
for (let i = 0; i < 400; i++) moods.push(moodOf(() => Math.floor(rand() * 101)));

const GOOD_THINGS = [
  [],
  ['散歩した'],
  ['散歩した', '', 'カフェ'],
  ['  空がきれい  ', '   ', '友達と話した'],
  ['　朝ごはん　', '　'],
  ['a', 'b', 'c'],
];
const toWebGoodThings = (list) => ({ goodThing1: list[0] ?? '', goodThing2: list[1] ?? '', goodThing3: list[2] ?? '' });

const moodAnalysis = moods.map((mood, i) => {
  const goodThings = GOOD_THINGS[i % GOOD_THINGS.length];
  const r = getFallbackAnalysis(mood, toWebGoodThings(goodThings));
  return { mood, goodThings, emotion: r.emotion, feedback: r.feedback, totalScore: r.totalScore };
});
const emotionKinds = new Set(moodAnalysis.map((c) => c.emotion));
if (emotionKinds.size !== 27) throw new Error(`感情タイプが ${emotionKinds.size} 種類しか出ていません`);

const moodColor = moods.map((mood) => {
  const c = generateMoodColor(mood);
  return { mood, color: { r: c.r, g: c.g, b: c.b } };
});

// starDataMaker.js の星座中心の計算をそのまま再現
const hashInputs = [...CONSTELLATIONS.map((c) => c.id), '', 'a', 'ノスタージア', 'x'.repeat(50)];
const constellationHash = hashInputs.map((input) => {
  const boxWidth = 60;
  const boxHeight = 60;
  const minX = -320 + boxWidth / 2 + 10;
  const maxX = 320 - boxWidth / 2 - 10;
  const minY = -160 + boxHeight / 2 + 10;
  const maxY = 160 - boxHeight / 2 - 10;
  const hash = hashCode(input);
  const prngX = (hash % 100) / 100;
  const prngY = ((hash * 13) % 100) / 100;
  const prngZ = ((hash * 17) % 100) / 100;
  return {
    input,
    hash,
    centerX: minX + prngX * (maxX - minX),
    centerY: minY + prngY * (maxY - minY),
    baseZ: -10 + prngZ * 15,
  };
});

const instants = [];
const base = new Date(2026, 0, 1, 0, 0, 0).getTime();
for (let h = 0; h < 72; h += 0.5) instants.push(base + h * 3600e3);
[
  [2026, 2, 1, 5, 59, 59], [2026, 2, 1, 6, 0, 0], [2026, 11, 31, 23, 59, 0],
  [2027, 0, 1, 5, 0, 0], [2028, 1, 29, 6, 0, 0], [2028, 2, 1, 3, 0, 0],
].forEach((a) => instants.push(new Date(...a).getTime()));
instants.push(new Date(2026, 10, 6, 6, 0, 0).getTime() - 1);
const diaryCycle = instants.map((at) => ({
  at,
  start: getDiaryCycleStart(new Date(at)).getTime(),
  end: getDiaryCycleEnd(new Date(at)).getTime(),
}));

const constellations = CONSTELLATIONS.map(({ id, name, starCount, description, features, history, starPositions, lines }) =>
  ({ id, name, starCount, description, features, history, starPositions, lines }));

const write = (dir, name, data) => writeFileSync(join(dir, name), `${JSON.stringify(data, null, 1)}\n`);
write(fixturesDir, 'mood_analysis.json', moodAnalysis);
write(fixturesDir, 'mood_color.json', moodColor);
write(fixturesDir, 'constellation_hash.json', constellationHash);
write(fixturesDir, 'diary_cycle.json', diaryCycle);
write(resourcesDir, 'constellations.json', constellations);
console.log(`mood ${moods.length} 件 / 感情タイプ ${emotionKinds.size} 種 / 星座 ${constellations.length} 個 / 時刻 ${instants.length} 件`);
