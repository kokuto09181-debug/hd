// movie.config.json を書き上げたあとの下読み。
// 写真の指定ミスと、当日ゲストが読み切れないコメントを、書き出す前に洗い出す。
import {existsSync} from 'node:fs';
import {readFile} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// --- 目安の根拠（README の「調べたこと」に出典を載せています） ---
// ゲストは「写真を見て」「コメントを読む」を同時にやるので、1秒あたり約4文字が限界とされる
const CHARS_PER_SECOND = 4;
// フェードイン・アウトで実際に読める時間は表示秒数より短い
const READING_OVERHEAD_SECONDS = 1;
const PHOTO_SECONDS_RANGE = [5, 8];
const TOTAL_MINUTES_RANGE = [5, 8];
const PHOTO_COUNT_RANGE = [30, 45];

const config = JSON.parse(await readFile(join(root, 'movie.config.json'), 'utf8'));
const {fps} = config.video;

const errors = [];
const warnings = [];

const countChars = (text) => text.replace(/\n/g, '').length;

let photoCount = 0;
let photoSeconds = 0;

for (const [sectionIndex, section] of config.sections.entries()) {
  const where = `章${sectionIndex + 1}「${section.title}」`;

  for (const [photoIndex, photo] of section.photos.entries()) {
    photoCount++;
    const seconds = photo.durationInSeconds ?? config.defaultPhotoDurationInSeconds;
    photoSeconds += seconds;
    const label = `${where} の ${photoIndex + 1}枚目 (${photo.src})`;

    if (!existsSync(join(root, 'public', photo.src))) {
      errors.push(`${label}: ファイルが見つかりません`);
    }

    if (seconds < PHOTO_SECONDS_RANGE[0] || seconds > PHOTO_SECONDS_RANGE[1]) {
      warnings.push(
        `${label}: ${seconds}秒。目安は${PHOTO_SECONDS_RANGE[0]}〜${PHOTO_SECONDS_RANGE[1]}秒です`,
      );
    }

    if (photo.caption) {
      const chars = countChars(photo.caption);
      const budget = Math.floor((seconds - READING_OVERHEAD_SECONDS) * CHARS_PER_SECOND);
      if (chars > budget) {
        warnings.push(
          `${label}: コメント${chars}文字は${seconds}秒では読み切れません` +
            `（この秒数で読めるのは約${budget}文字。文を削るか、表示を約${
              Math.ceil(chars / CHARS_PER_SECOND) + READING_OVERHEAD_SECONDS
            }秒に伸ばしてください）`,
        );
      }
      const lines = photo.caption.split('\n');
      if (lines.length > 2) {
        warnings.push(`${label}: コメントが${lines.length}行あります。2行までが読みやすいです`);
      }
    }
  }
}

// 尺は timeline.ts と同じ計算（シーンは重ねてつなぐので、その分だけ短くなる）
const transition = Math.max(1, Math.round(config.transitionInSeconds * fps));
const clamp = (frames) => Math.max(frames, transition * 2 + 1);
const sceneFrames = [
  clamp(Math.round(config.opening.durationInSeconds * fps)),
  ...config.sections.flatMap((section) => [
    clamp(Math.round((section.cardDurationInSeconds ?? 4) * fps)),
    ...section.photos.map((photo) =>
      clamp(
        Math.round(
          (photo.durationInSeconds ?? config.defaultPhotoDurationInSeconds) * fps,
        ),
      ),
    ),
  ]),
  clamp(Math.round(config.ending.durationInSeconds * fps)),
];
const totalFrames =
  sceneFrames.reduce((a, b) => a + b, 0) - transition * (sceneFrames.length - 1);
const totalSeconds = totalFrames / fps;
const minutes = Math.floor(totalSeconds / 60);
const seconds = Math.round(totalSeconds % 60);

console.log(`尺        ${minutes}分${String(seconds).padStart(2, '0')}秒（${totalFrames}フレーム）`);
console.log(`写真      ${photoCount}枚 / 章 ${config.sections.length}つ`);
console.log(
  `画面      ${config.video.width}×${config.video.height} ` +
    `(${(config.video.width / config.video.height).toFixed(2)}:1) ${fps}fps`,
);
console.log(
  '章の配分  ' +
    config.sections
      .map((section) => `${section.title}=${section.photos.length}枚`)
      .join(' / '),
);
console.log('');

if (totalSeconds < TOTAL_MINUTES_RANGE[0] * 60) {
  warnings.push(
    `全体が${minutes}分${seconds}秒です。一般的な目安は${TOTAL_MINUTES_RANGE[0]}〜${TOTAL_MINUTES_RANGE[1]}分なので、少し短めです`,
  );
} else if (totalSeconds > TOTAL_MINUTES_RANGE[1] * 60) {
  warnings.push(
    `全体が${minutes}分${seconds}秒です。${TOTAL_MINUTES_RANGE[1]}分を超えるとゲストの集中が切れやすいので、写真を減らすことを検討してください`,
  );
}

if (photoCount < PHOTO_COUNT_RANGE[0]) {
  warnings.push(
    `写真が${photoCount}枚です。${PHOTO_COUNT_RANGE[0]}〜${PHOTO_COUNT_RANGE[1]}枚が一般的な目安です`,
  );
}

const ratio = config.video.width / config.video.height;
if (Math.abs(ratio - 16 / 9) > 0.01 && Math.abs(ratio - 4 / 3) > 0.01) {
  warnings.push(
    `画面比率が ${ratio.toFixed(2)}:1 です。式場のプロジェクタは 16:9 か 4:3 がほとんどです`,
  );
}

for (const warning of warnings) console.log(`  注意  ${warning}`);
for (const error of errors) console.log(`  エラー ${error}`);

console.log('');
if (errors.length) {
  console.log(`エラー ${errors.length}件。このままでは書き出せません。`);
  process.exit(1);
}
console.log(
  warnings.length
    ? `注意 ${warnings.length}件。直さなくても書き出せますが、一度目を通してください。`
    : '問題は見つかりませんでした。',
);
