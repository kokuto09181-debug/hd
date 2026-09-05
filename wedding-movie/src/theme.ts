/**
 * 会場のプロジェクタは色が浅く出るので、白飛びしない生成り色を地にして
 * 文字は真っ黒ではなく墨色にしている。
 */
export const theme = {
  paper: '#F4EFE7',
  paperDeep: '#E7DFD3',
  ink: '#3A3129',
  inkSoft: '#7A6E60',
  accent: '#A98C63',
  mincho: '"Zen Old Mincho", serif',
  gothic: '"Zen Kaku Gothic New", sans-serif',
  latin: '"Cormorant Garamond", serif',
} as const;

/**
 * 式場のプロジェクタは画面の上下左右 5〜10% を切り落とすことがある。
 * 業界の目安は「文字は端から 10〜15% 空ける」なので、
 * 文字はタイトルセーフ(10%)の内側、写真はアクションセーフ(5%)の内側に置く。
 */
export const SAFE_AREA_PERCENT = 10;
export const ACTION_SAFE_PERCENT = 5;

/**
 * CSS の % パディングは上下も「幅」を基準にしてしまうので、
 * 縦と横をそれぞれの辺から計算して px で返す。
 */
export const safePadding = (width: number, height: number, percent: number) =>
  `${(height * percent) / 100}px ${(width * percent) / 100}px`;
