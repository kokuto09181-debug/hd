// Google Fonts から本編で使う書体をダウンロードして public/fonts に置く。
// 一度実行すればオフラインでもレンダリングできる。
import {mkdir, writeFile, stat} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = join(root, 'public', 'fonts');

const FONTS = [
  {file: 'ZenOldMincho-Regular.ttf', family: 'Zen+Old+Mincho', weight: 400},
  {file: 'ZenOldMincho-SemiBold.ttf', family: 'Zen+Old+Mincho', weight: 600},
  {file: 'ZenKakuGothicNew-Regular.ttf', family: 'Zen+Kaku+Gothic+New', weight: 400},
  {file: 'CormorantGaramond-Light.ttf', family: 'Cormorant+Garamond', weight: 300},
];

const cssFor = async ({family, weight}) => {
  const url = `https://fonts.googleapis.com/css2?family=${family}:wght@${weight}&display=swap`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${family} の CSS 取得に失敗 (${res.status})`);
  const css = await res.text();
  const m = css.match(/https:\/\/fonts\.gstatic\.com\/[^)]+\.ttf/);
  if (!m) throw new Error(`${family} の ttf URL が見つかりませんでした`);
  return m[0];
};

await mkdir(outDir, {recursive: true});

for (const font of FONTS) {
  const dest = join(outDir, font.file);
  try {
    const s = await stat(dest);
    if (s.size > 0) {
      console.log(`skip  ${font.file} (取得済み ${(s.size / 1024 / 1024).toFixed(1)}MB)`);
      continue;
    }
  } catch {
    // まだ無いので取りに行く
  }
  const ttfUrl = await cssFor(font);
  const res = await fetch(ttfUrl);
  if (!res.ok) throw new Error(`${font.file} のダウンロードに失敗 (${res.status})`);
  const buf = Buffer.from(await res.arrayBuffer());
  await writeFile(dest, buf);
  console.log(`saved ${font.file} (${(buf.length / 1024 / 1024).toFixed(1)}MB)`);
}

console.log('\nフォントの準備が完了しました。');
