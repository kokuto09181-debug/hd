// 指定フレームの静止画を書き出す。全部レンダリングせずに見た目を確認したいとき用。
// 例: npm run still -- 400 out/check.png
import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
// Remotion は旧 headless モードで起動するので、chrome-headless-shell を優先して探す
const LOCAL_CHROMIUM = [
  '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell',
  '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
];
const browser = LOCAL_CHROMIUM.find((path) => existsSync(path));

const frame = process.argv[2] ?? '0';
const output = process.argv[3] ?? `out/still-${frame}.png`;

const result = spawnSync(
  'npx',
  [
    'remotion',
    'still',
    'ProfileMovie',
    output,
    `--frame=${frame}`,
    ...(browser ? [`--browser-executable=${browser}`] : []),
  ],
  {cwd: root, stdio: 'inherit'},
);

process.exit(result.status ?? 1);
