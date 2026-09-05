// public/photos/ に置いた写真を読み取って、movie.config.json の雛形を作る。
// 既存の movie.config.json は上書きせず、コメントだけ空の新しいファイルを書き出す。
import {readdir, writeFile, readFile} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const photosRoot = join(root, 'public', 'photos');
const outFile = join(root, 'movie.config.generated.json');

const IMAGE_EXT = /\.(jpe?g|png|webp|avif)$/i;

/** 01.jpg, 02.jpg … のように番号が付いていれば数値順、なければ名前順に並べる */
const naturalSort = (a, b) =>
  a.localeCompare(b, 'ja', {numeric: true, sensitivity: 'base'});

const dirs = (await readdir(photosRoot, {withFileTypes: true}))
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .sort(naturalSort);

if (dirs.length === 0) {
  console.error(
    'public/photos/ の下にフォルダがありません。\n' +
      '例: public/photos/01_groom/ public/photos/02_bride/ public/photos/03_together/',
  );
  process.exit(1);
}

const sections = [];
for (const dir of dirs) {
  const files = (await readdir(join(photosRoot, dir)))
    .filter((name) => IMAGE_EXT.test(name))
    .sort(naturalSort);
  if (files.length === 0) continue;
  sections.push({
    label: '',
    title: dir,
    subtitle: '',
    cardDurationInSeconds: 4.5,
    photos: files.map((name) => ({
      src: `photos/${dir}/${name}`,
      label: '',
      caption: '',
    })),
  });
}

// 既存の設定があれば、写真以外の項目（ふたりの名前や挙式日）は引き継ぐ
let base;
try {
  base = JSON.parse(await readFile(join(root, 'movie.config.json'), 'utf8'));
} catch {
  base = null;
}

const generated = {
  _readme: 'scaffold で生成しました。label と caption を埋めて movie.config.json に置き換えてください。',
  video: base?.video ?? {width: 1920, height: 1080, fps: 30},
  transitionInSeconds: base?.transitionInSeconds ?? 0.8,
  defaultPhotoDurationInSeconds: base?.defaultPhotoDurationInSeconds ?? 6,
  opening: base?.opening ?? {
    label: 'Profile Movie',
    names: '',
    title: '',
    date: '',
    durationInSeconds: 7,
  },
  sections,
  ending: base?.ending ?? {
    label: 'Thank You',
    lines: [''],
    signature: '',
    date: '',
    durationInSeconds: 14,
  },
};

await writeFile(outFile, JSON.stringify(generated, null, 2) + '\n', 'utf8');

const total = sections.reduce((acc, section) => acc + section.photos.length, 0);
console.log(`movie.config.generated.json を書き出しました（${sections.length}章 / 写真${total}枚）。`);
console.log('コメントを埋めたら movie.config.json にリネームしてください。');
