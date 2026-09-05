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
 * 式場のプロジェクタは画面の端を数%切り落とすことがある。
 * 文字はこの内側にだけ置く。
 */
export const SAFE_AREA_PERCENT = 6;
