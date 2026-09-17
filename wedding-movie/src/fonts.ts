import {loadFont} from '@remotion/fonts';
import {continueRender, delayRender, staticFile} from 'remotion';
import {FONT_FILES} from './themes/font-files.mjs';

/**
 * 書体は public/fonts に置いたローカルファイルから読む（`npm run setup` で取得）。
 * CDN に取りに行かないので、レンダリング中に通信が落ちても崩れない。
 */
const handle = delayRender('書体を読み込んでいます');

Promise.all(
  FONT_FILES.map(({css, file, weight, style}) =>
    loadFont({
      family: css,
      url: staticFile(`fonts/${file}`),
      weight,
      style,
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
