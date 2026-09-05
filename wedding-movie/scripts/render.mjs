// mp4 を書き出す。BGM は後から載せる前提なので、中身は無音。
// ただし音声トラック自体は残している（会場のプレイヤーやDVDオーサリングが
// 音声トラックの無いファイルでつまずくことがあるため）。外すなら --muted。
import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// この環境に入っている Chromium があればそれを使う（無ければ Remotion が自前で用意する）
// Remotion は旧 headless モードで起動するので、chrome-headless-shell を優先して探す
const LOCAL_CHROMIUM = [
  '/opt/pw-browsers/chromium_headless_shell-1194/chrome-linux/headless_shell',
  '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
];
const browser = LOCAL_CHROMIUM.find((path) => existsSync(path));

const args = process.argv.slice(2);
const output = args.find((arg) => !arg.startsWith('-')) ?? 'out/profile-movie.mp4';
const passthrough = args.filter((arg) => arg.startsWith('-'));

const result = spawnSync(
  'npx',
  [
    'remotion',
    'render',
    'ProfileMovie',
    output,
    '--codec=h264',
    // 会場のプレイヤーでも確実に再生できる、素直な H.264 + yuv420p にしておく
    '--pixel-format=yuv420p',
    // これを付けないとフルレンジ(yuvj420p)で出てしまい、
    // テレビレンジ前提のプレイヤーやプロジェクタでは色が浅く/潰れて見える
    '--color-space=bt709',
    '--crf=18',
    ...(browser ? [`--browser-executable=${browser}`] : []),
    ...passthrough,
  ],
  {cwd: root, stdio: 'inherit'},
);

process.exit(result.status ?? 1);
