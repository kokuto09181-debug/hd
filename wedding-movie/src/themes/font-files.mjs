// 全テーマで使う書体の一覧。scripts/fetch-fonts.mjs と src/fonts.ts の両方から読む。
// family / spec は Google Fonts の css2 API の書き方そのまま。
export const FONT_FILES = [
  // クラシック・和モダン
  {file: 'ZenOldMincho-Regular.ttf', family: 'Zen+Old+Mincho', spec: 'wght@400', css: 'Zen Old Mincho', weight: '400', style: 'normal'},
  {file: 'ZenOldMincho-SemiBold.ttf', family: 'Zen+Old+Mincho', spec: 'wght@600', css: 'Zen Old Mincho', weight: '600', style: 'normal'},
  {file: 'ShipporiMincho-Medium.ttf', family: 'Shippori+Mincho', spec: 'wght@500', css: 'Shippori Mincho', weight: '500', style: 'normal'},
  {file: 'ShipporiMincho-Bold.ttf', family: 'Shippori+Mincho', spec: 'wght@700', css: 'Shippori Mincho', weight: '700', style: 'normal'},
  // ゴシック（シネマ・ミニマル・マガジン）
  {file: 'ZenKakuGothicNew-Light.ttf', family: 'Zen+Kaku+Gothic+New', spec: 'wght@300', css: 'Zen Kaku Gothic New', weight: '300', style: 'normal'},
  {file: 'ZenKakuGothicNew-Regular.ttf', family: 'Zen+Kaku+Gothic+New', spec: 'wght@400', css: 'Zen Kaku Gothic New', weight: '400', style: 'normal'},
  {file: 'ZenKakuGothicNew-Bold.ttf', family: 'Zen+Kaku+Gothic+New', spec: 'wght@700', css: 'Zen Kaku Gothic New', weight: '700', style: 'normal'},
  {file: 'ZenKakuGothicNew-Black.ttf', family: 'Zen+Kaku+Gothic+New', spec: 'wght@900', css: 'Zen Kaku Gothic New', weight: '900', style: 'normal'},
  // 手書き風（ナチュラル）
  {file: 'KleeOne-Regular.ttf', family: 'Klee+One', spec: 'wght@400', css: 'Klee One', weight: '400', style: 'normal'},
  {file: 'KleeOne-SemiBold.ttf', family: 'Klee+One', spec: 'wght@600', css: 'Klee One', weight: '600', style: 'normal'},
  // 丸ゴシック（ポップ）
  {file: 'ZenMaruGothic-Bold.ttf', family: 'Zen+Maru+Gothic', spec: 'wght@700', css: 'Zen Maru Gothic', weight: '700', style: 'normal'},
  {file: 'ZenMaruGothic-Black.ttf', family: 'Zen+Maru+Gothic', spec: 'wght@900', css: 'Zen Maru Gothic', weight: '900', style: 'normal'},
  // 欧文
  {file: 'CormorantGaramond-Light.ttf', family: 'Cormorant+Garamond', spec: 'wght@300', css: 'Cormorant Garamond', weight: '300', style: 'normal'},
  {file: 'CormorantGaramond-LightItalic.ttf', family: 'Cormorant+Garamond', spec: 'ital,wght@1,300', css: 'Cormorant Garamond', weight: '300', style: 'italic'},
  {file: 'PlayfairDisplay-Italic.ttf', family: 'Playfair+Display', spec: 'ital,wght@1,400', css: 'Playfair Display', weight: '400', style: 'italic'},
  {file: 'Montserrat-Light.ttf', family: 'Montserrat', spec: 'wght@300', css: 'Montserrat', weight: '300', style: 'normal'},
  {file: 'Montserrat-Medium.ttf', family: 'Montserrat', spec: 'wght@500', css: 'Montserrat', weight: '500', style: 'normal'},
  {file: 'CourierPrime-Regular.ttf', family: 'Courier+Prime', spec: 'wght@400', css: 'Courier Prime', weight: '400', style: 'normal'},
  {file: 'CourierPrime-Bold.ttf', family: 'Courier+Prime', spec: 'wght@700', css: 'Courier Prime', weight: '700', style: 'normal'},
  {file: 'DMSans-Light.ttf', family: 'DM+Sans', spec: 'wght@300', css: 'DM Sans', weight: '300', style: 'normal'},
  {file: 'Nunito-ExtraBold.ttf', family: 'Nunito', spec: 'wght@800', css: 'Nunito', weight: '800', style: 'normal'},
  {file: 'Oswald-Medium.ttf', family: 'Oswald', spec: 'wght@500', css: 'Oswald', weight: '500', style: 'normal'},
];
