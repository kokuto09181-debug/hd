// 本物の写真を入れる前に、通しで動くか確認するためのダミー画像を作る。
// 縦・横・正方形を混ぜてあるので、写真の向きがバラバラでも崩れないか確認できる。
import {deflateSync} from 'node:zlib';
import {mkdir, writeFile} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

const crcTable = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c;
  }
  return table;
})();

const crc32 = (buf) => {
  let c = -1;
  for (const byte of buf) c = crcTable[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
};

const chunk = (type, data) => {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
};

const encodePng = (width, height, rgb) => {
  const stride = width * 3;
  const raw = Buffer.alloc((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0; // フィルタなし
    rgb.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // truecolor
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, {level: 6})),
    chunk('IEND', Buffer.alloc(0)),
  ]);
};

// 数字を7セグメント風に描くための、点灯するセグメントの組み合わせ
const SEGMENTS = {
  0: 'abcdef', 1: 'bc', 2: 'abged', 3: 'abgcd', 4: 'fgbc',
  5: 'afgcd', 6: 'afgecd', 7: 'abc', 8: 'abcdefg', 9: 'abcfgd',
};

const drawRect = (rgb, width, x0, y0, w, h, color) => {
  for (let y = y0; y < y0 + h; y++) {
    for (let x = x0; x < x0 + w; x++) {
      const i = (y * width + x) * 3;
      rgb[i] = color[0];
      rgb[i + 1] = color[1];
      rgb[i + 2] = color[2];
    }
  }
};

const drawDigit = (rgb, width, digit, x, y, size, color) => {
  const t = Math.max(2, Math.round(size * 0.14)); // セグメントの太さ
  const w = size * 0.6;
  const h = size;
  const on = SEGMENTS[digit] ?? '';
  const seg = {
    a: [x, y, w, t],
    b: [x + w - t, y, t, h / 2],
    c: [x + w - t, y + h / 2, t, h / 2],
    d: [x, y + h - t, w, t],
    e: [x, y + h / 2, t, h / 2],
    f: [x, y, t, h / 2],
    g: [x, y + h / 2 - t / 2, w, t],
  };
  for (const key of on) {
    const [sx, sy, sw, sh] = seg[key];
    drawRect(rgb, width, Math.round(sx), Math.round(sy), Math.round(sw), Math.round(sh), color);
  }
};

const SHAPES = [
  [1600, 1200], // 横
  [1200, 1600], // 縦
  [1920, 1080], // ワイド
  [1400, 1400], // 正方形
];

const PALETTES = [
  [[214, 196, 170], [150, 122, 95]],
  [[196, 206, 200], [104, 128, 118]],
  [[220, 200, 196], [156, 112, 108]],
  [[204, 200, 216], [116, 108, 140]],
];

const GROUPS = [
  {dir: 'photos/01_groom', count: 10},
  {dir: 'photos/02_bride', count: 10},
  {dir: 'photos/03_together', count: 8},
];

let made = 0;
for (const [groupIndex, group] of GROUPS.entries()) {
  await mkdir(join(root, 'public', group.dir), {recursive: true});
  for (let n = 1; n <= group.count; n++) {
    const [width, height] = SHAPES[(n - 1) % SHAPES.length];
    const [bg, fg] = PALETTES[(groupIndex + n) % PALETTES.length];
    const rgb = Buffer.alloc(width * height * 3);

    // 斜めのグラデーションで地を塗る
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const t = (x / width + y / height) / 2;
        const i = (y * width + x) * 3;
        rgb[i] = Math.round(bg[0] * (1 - t * 0.35));
        rgb[i + 1] = Math.round(bg[1] * (1 - t * 0.35));
        rgb[i + 2] = Math.round(bg[2] * (1 - t * 0.35));
      }
    }

    const size = Math.round(Math.min(width, height) * 0.34);
    const digits = String(n).split('').map(Number);
    const totalW = digits.length * size * 0.75;
    let cursor = (width - totalW) / 2;
    for (const digit of digits) {
      drawDigit(rgb, width, digit, cursor, (height - size) / 2, size, fg);
      cursor += size * 0.75;
    }

    const file = join(root, 'public', group.dir, `${String(n).padStart(2, '0')}.png`);
    await writeFile(file, encodePng(width, height, rgb));
    made++;
  }
}

console.log(`ダミー画像を ${made} 枚つくりました（public/photos/ 以下）。`);
console.log('本番では同じファイル名で実際の写真に差し替えてください。');
