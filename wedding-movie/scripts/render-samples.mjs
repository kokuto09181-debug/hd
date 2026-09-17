// 全テーマの見比べ用に、短い抜粋の mp4 と、主要4シーンの静止画を書き出す。
// bundle は一度だけ作って使い回すので、テーマ数が増えても速い。
import {bundle} from '@remotion/bundler';
import {renderMedia, renderStill, selectComposition} from '@remotion/renderer';
import {existsSync} from 'node:fs';
import {mkdir} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'out', 'samples');

const LOCAL_CHROMIUM = [
  '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell',
  '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
];
const browserExecutable = LOCAL_CHROMIUM.find((path) => existsSync(path)) ?? null;

const only = process.argv.slice(2).filter((a) => !a.startsWith('-'));
const stillsOnly = process.argv.includes('--stills');

const {themes} = await import(join(root, 'src', 'themes', 'index.ts')).catch(() => ({themes: null}));
// TS を直接 import できない環境向けに id の一覧だけ持つ
const THEME_IDS = themes?.map((t) => t.id) ?? [
  'classic', 'cinema', 'natural', 'vintage', 'minimal', 'pop', 'wa', 'editorial',
];
const targets = only.length ? THEME_IDS.filter((id) => only.includes(id)) : THEME_IDS;

// テーマ定義（TS）から遷移秒数だけ拾う。静止画を切るコマの計算に使う
import {readFileSync} from 'node:fs';
const transitionSeconds = (id) => {
  const src = readFileSync(join(root, 'src', 'themes', `${id}.ts`), 'utf8');
  const m = src.match(/transition:\s*\{[^}]*seconds:\s*([\d.]+)/);
  return m ? Number(m[1]) : 0.8;
};

await mkdir(outDir, {recursive: true});

console.log('bundle を作成中…');
const serveUrl = await bundle({
  entryPoint: join(root, 'src', 'index.ts'),
  publicDir: join(root, 'public'),
});

for (const id of targets) {
  const compositionId = `Sample-${id}`;
  const composition = await selectComposition({serveUrl, id: compositionId, browserExecutable});
  const {durationInFrames, fps} = composition;
  console.log(`\n[${id}] ${durationInFrames}f (${(durationInFrames / fps).toFixed(1)}s)`);

  // 抜粋の構成（src/sample.ts と同じ）: opening 5s / section 3.5s / 写真 5s×3 / ending 7s
  // シーンは遷移ぶん重なるので、開始位置 = それまでの合計 − 遷移×回数
  const tSec = transitionSeconds(id);
  const tr = Math.round(tSec * fps);
  const durations = [5, 3.5, 5, 5, 5, 7].map((sec) => Math.max(Math.round(sec * fps), tr * 2 + 1));
  const starts = [];
  let acc = 0;
  durations.forEach((d, i) => {
    starts.push(acc - tr * i);
    acc += d;
  });
  const mid = (i) => starts[i] + Math.round(durations[i] / 2);
  const frames = {
    opening: mid(0),
    section: mid(1),
    photo1: mid(2),
    photo2: mid(3),
    ending: starts[5] + Math.round(fps * 4.5),
  };

  for (const [name, frame] of Object.entries(frames)) {
    const output = join(outDir, `${id}-${name}.png`);
    await renderStill({
      composition,
      serveUrl,
      output,
      frame: Math.max(0, Math.min(durationInFrames - 1, frame)),
      browserExecutable,
      imageFormat: 'png',
    });
    process.stdout.write(`  ${name} `);
  }
  console.log('');

  if (stillsOnly) continue;

  const output = join(outDir, `${id}.mp4`);
  await renderMedia({
    composition,
    serveUrl,
    codec: 'h264',
    outputLocation: output,
    browserExecutable,
    pixelFormat: 'yuv420p',
    colorSpace: 'bt709',
    crf: 20,
    onProgress: ({renderedFrames}) => {
      if (renderedFrames % 60 === 0) process.stdout.write(`  ${renderedFrames}/${durationInFrames}\r`);
    },
  });
  console.log(`  → ${output}`);
}

console.log('\n完了: out/samples/');
