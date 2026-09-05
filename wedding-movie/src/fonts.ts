import {loadFont} from '@remotion/fonts';
import {continueRender, delayRender, staticFile} from 'remotion';

/**
 * 書体は public/fonts に置いたローカルファイルから読む（`npm run setup` で取得）。
 * CDN に取りに行かないので、レンダリング中に通信が落ちても崩れない。
 */
const handle = delayRender('書体を読み込んでいます');

const FONTS = [
  {family: 'Zen Old Mincho', file: 'ZenOldMincho-Regular.ttf', weight: '400'},
  {family: 'Zen Old Mincho', file: 'ZenOldMincho-SemiBold.ttf', weight: '600'},
  {family: 'Zen Kaku Gothic New', file: 'ZenKakuGothicNew-Regular.ttf', weight: '400'},
  {family: 'Cormorant Garamond', file: 'CormorantGaramond-Light.ttf', weight: '300'},
];

Promise.all(
  FONTS.map(({family, file, weight}) =>
    loadFont({
      family,
      url: staticFile(`fonts/${file}`),
      weight,
      format: 'truetype',
      display: 'block',
    }),
  ),
)
  .then(() => continueRender(handle))
  .catch((err) => {
    // 書体が無いまま進むと文字が別のフォントで出てしまうので、原因を明示して止める
    throw new Error(
      `書体の読み込みに失敗しました。先に \`npm run setup\` を実行してください。\n${String(err)}`,
    );
  });
