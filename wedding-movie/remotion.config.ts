import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
// 写真の階調を落としたくないので品質は高めに固定
Config.setJpegQuality(95);

// setChromiumOpenGlRenderer はあえて指定しない。
// Remotion 同梱の changelog によると 'angle' は長いレンダリングを
// クラッシュさせうるメモリリークがあり、v4 の既定値ではない。
// プロフィールムービーは数千フレームの長丁場なので、既定のまま回す。
